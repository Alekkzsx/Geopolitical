from __future__ import annotations

import json
import math
import tempfile
import urllib.request
import zipfile
from pathlib import Path

try:
    import shapefile
except ImportError as exc:  # pragma: no cover - build-time helper
    raise SystemExit("Missing dependency 'pyshp'. Install it with: python -m pip install pyshp") from exc


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
OUTPUT_PATH = DATA_DIR / "map_countries.json"

COUNTRIES_URL = "https://naciscdn.org/naturalearth/50m/cultural/ne_50m_admin_0_countries.zip"
PLACES_URL = "https://naciscdn.org/naturalearth/10m/cultural/ne_10m_populated_places.zip"

SCALE = 10.0
WORLD_WIDTH = 360.0 * SCALE
HALF_WIDTH = WORLD_WIDTH / 2.0

PLACE_PRIORITY = {
    "Admin-0 capital": 3,
    "Admin-0 capital alt": 2,
    "Admin-0 region capital": 1,
}

MANUAL_CAPITALS = {
    "CYN": {"name": "North Nicosia", "lon": 33.3667, "lat": 35.1833},
    "GGY": {"name": "Saint Peter Port", "lon": -2.5369, "lat": 49.4550},
    "JEY": {"name": "Saint Helier", "lon": -2.1049, "lat": 49.1868},
    "NRU": {"name": "Yaren District", "lon": 166.9209, "lat": -0.5477},
    "SDS": {"name": "Juba", "lon": 31.5825, "lat": 4.8594},
    "SXM": {"name": "Philipsburg", "lon": -63.0538, "lat": 18.0260},
}


def _download_and_extract(url: str, target_dir: Path) -> Path:
    zip_path = target_dir / Path(url).name
    with urllib.request.urlopen(url) as response:
        zip_path.write_bytes(response.read())

    extract_dir = target_dir / zip_path.stem
    with zipfile.ZipFile(zip_path) as archive:
        archive.extractall(extract_dir)
    return extract_dir


def _reader_for(path: Path) -> shapefile.Reader:
    shp_path = next(path.glob("*.shp"))
    return shapefile.Reader(str(shp_path), encoding="latin1")


def _round(value: float) -> float:
    return round(float(value), 3)


def _project_point(lon: float, lat: float) -> list[float]:
    return [_round(lon * SCALE), _round(-lat * SCALE)]


def _clean_text(value: str) -> str:
    return " ".join(str(value).split())


def _ring_area(points: list[list[float]]) -> float:
    if len(points) < 3:
        return 0.0

    area = 0.0
    for index, point in enumerate(points):
        next_point = points[(index + 1) % len(points)]
        area += point[0] * next_point[1] - next_point[0] * point[1]
    return abs(area) * 0.5


def _ring_centroid(points: list[list[float]]) -> list[float]:
    if len(points) < 3:
        return [0.0, 0.0]

    signed_area = 0.0
    centroid_x = 0.0
    centroid_y = 0.0
    for index, point in enumerate(points):
        next_point = points[(index + 1) % len(points)]
        cross = point[0] * next_point[1] - next_point[0] * point[1]
        signed_area += cross
        centroid_x += (point[0] + next_point[0]) * cross
        centroid_y += (point[1] + next_point[1]) * cross

    if abs(signed_area) < 0.0001:
        average_x = sum(point[0] for point in points) / len(points)
        average_y = sum(point[1] for point in points) / len(points)
        return [_round(average_x), _round(average_y)]

    signed_area *= 0.5
    factor = 1.0 / (6.0 * signed_area)
    return [_round(centroid_x * factor), _round(centroid_y * factor)]


def _wrap_world_x(value: float) -> float:
    return ((value + HALF_WIDTH) % WORLD_WIDTH) - HALF_WIDTH


def _wrap_near(value: float, reference: float) -> float:
    candidates = [value - WORLD_WIDTH, value, value + WORLD_WIDTH]
    return min(candidates, key=lambda candidate: abs(candidate - reference))


def _circular_bounds(xs: list[float]) -> tuple[float, float]:
    if not xs:
        return 0.0, 0.0

    normalized = sorted((x + HALF_WIDTH) % WORLD_WIDTH for x in xs)
    if len(normalized) == 1:
        return _wrap_world_x(normalized[0] - HALF_WIDTH), 0.0

    max_gap = -1.0
    max_gap_index = 0
    for index in range(len(normalized)):
        current = normalized[index]
        next_value = normalized[(index + 1) % len(normalized)]
        gap = next_value - current
        if index == len(normalized) - 1:
            gap = normalized[0] + WORLD_WIDTH - current
        if gap > max_gap:
            max_gap = gap
            max_gap_index = index

    width = WORLD_WIDTH - max_gap
    start = normalized[(max_gap_index + 1) % len(normalized)]
    center = start + width * 0.5
    return _wrap_world_x(center - HALF_WIDTH), _round(width)


def _compute_importance(record: shapefile.ShapeRecord, field_index: dict[str, int]) -> float:
    labelrank = float(record.record[field_index["LABELRANK"]] or 8.0)
    scalerank = float(record.record[field_index["scalerank"]] or 10.0)
    pop_est = max(float(record.record[field_index["POP_EST"]] or 0.0), 0.0)

    label_component = max(0.0, 1.0 - ((labelrank - 1.0) / 7.0))
    scale_component = max(0.0, 1.0 - ((scalerank - 1.0) / 9.0))
    pop_component = min(math.log10(pop_est + 1.0) / 10.0, 1.0)

    importance = (label_component * 0.55) + (scale_component * 0.25) + (pop_component * 0.20)
    return _round(max(0.05, min(importance, 1.0)))


def _build_capital_index(reader: shapefile.Reader) -> dict[str, dict[str, float | str]]:
    field_names = [field[0] for field in reader.fields[1:]]
    field_index = {name: index for index, name in enumerate(field_names)}

    capitals: dict[str, tuple[tuple[int, float, int], dict[str, float | str]]] = {}
    for shape_record in reader.iterShapeRecords():
        feature_class = shape_record.record[field_index["FEATURECLA"]]
        if feature_class not in PLACE_PRIORITY:
            continue

        country_id = shape_record.record[field_index["ADM0_A3"]]
        score = (
            PLACE_PRIORITY[feature_class],
            float(shape_record.record[field_index.get("POP_MAX", 0)] or 0.0),
            -int(shape_record.record[field_index.get("LABELRANK", 0)] or 99),
        )
        candidate = {
            "name": _clean_text(shape_record.record[field_index["NAME"]]),
            "lon": float(shape_record.record[field_index["LONGITUDE"]]),
            "lat": float(shape_record.record[field_index["LATITUDE"]]),
        }

        current = capitals.get(country_id)
        if current is None or score > current[0]:
            capitals[country_id] = (score, candidate)

    capital_index = {country_id: data for country_id, (_, data) in capitals.items()}
    capital_index.update(MANUAL_CAPITALS)
    return capital_index


def _largest_polygon(polygons: list[list[list[float]]]) -> list[list[float]]:
    if not polygons:
        return []
    return max(polygons, key=_ring_area)


def _shift_ring(ring: list[list[float]], center_x: float) -> list[list[float]]:
    average_x = sum(point[0] for point in ring) / len(ring)
    offset = min(
        (-WORLD_WIDTH, 0.0, WORLD_WIDTH),
        key=lambda candidate: abs((average_x + candidate) - center_x),
    )
    return [[_round(point[0] + offset), point[1]] for point in ring]


def main() -> None:
    simulation_data = json.loads((DATA_DIR / "countries.json").read_text(encoding="utf-8"))
    simulation_ids = set(simulation_data.keys())

    with tempfile.TemporaryDirectory() as temp_dir_raw:
        temp_dir = Path(temp_dir_raw)
        countries_dir = _download_and_extract(COUNTRIES_URL, temp_dir)
        places_dir = _download_and_extract(PLACES_URL, temp_dir)

        countries_reader = _reader_for(countries_dir)
        capitals_reader = _reader_for(places_dir)
        try:
            capital_index = _build_capital_index(capitals_reader)

            field_names = [field[0] for field in countries_reader.fields[1:]]
            field_index = {name: index for index, name in enumerate(field_names)}
            countries_output: dict[str, dict[str, object]] = {}

            for shape_record in countries_reader.iterShapeRecords():
                record = shape_record.record
                geometry = shape_record.shape.__geo_interface__
                geometry_type = geometry["type"]
                if geometry_type not in {"Polygon", "MultiPolygon"}:
                    continue

                country_id = record[field_index["ADM0_A3"]]
                display_name = _clean_text(record[field_index["NAME"]])

                raw_polygons = geometry["coordinates"] if geometry_type == "MultiPolygon" else [geometry["coordinates"]]
                projected_polygons: list[list[list[float]]] = []
                all_xs: list[float] = []
                all_ys: list[float] = []

                for polygon in raw_polygons:
                    if not polygon:
                        continue
                    exterior_ring = polygon[0]
                    if len(exterior_ring) < 3:
                        continue

                    points = [_project_point(lon, lat) for lon, lat in exterior_ring]
                    projected_polygons.append(points)
                    all_xs.extend(point[0] for point in points)
                    all_ys.extend(point[1] for point in points)

                if not projected_polygons:
                    continue

                bbox_center_x, bbox_width = _circular_bounds(all_xs)
                shifted_polygons = [_shift_ring(ring, bbox_center_x) for ring in projected_polygons]
                shifted_ys = [point[1] for ring in shifted_polygons for point in ring]

                largest_polygon = _largest_polygon(shifted_polygons)
                fallback_anchor = _ring_centroid(largest_polygon)

                label_x = record[field_index["LABEL_X"]]
                label_y = record[field_index["LABEL_Y"]]
                if label_x in (None, "") or label_y in (None, ""):
                    label_anchor = fallback_anchor
                else:
                    projected_anchor = _project_point(float(label_x), float(label_y))
                    label_anchor = [_round(_wrap_near(projected_anchor[0], bbox_center_x)), projected_anchor[1]]

                capital = capital_index.get(country_id)
                if capital:
                    capital_coord = _project_point(float(capital["lon"]), float(capital["lat"]))
                    capital_coord[0] = _round(_wrap_near(capital_coord[0], bbox_center_x))
                    capital_name = _clean_text(capital["name"])
                else:
                    capital_coord = []
                    capital_name = ""

                bbox_height = _round(max(shifted_ys) - min(shifted_ys))
                bbox_top_left_x = _round(_wrap_world_x(bbox_center_x - (bbox_width * 0.5)))
                bbox_top_left_y = _round(min(shifted_ys))

                countries_output[country_id] = {
                    "id": country_id,
                    "display_name": display_name,
                    "polygons": shifted_polygons,
                    "bbox": {
                        "position": [bbox_top_left_x, bbox_top_left_y],
                        "size": [bbox_width, bbox_height],
                        "center": [_round(bbox_center_x), _round((min(shifted_ys) + max(shifted_ys)) * 0.5)],
                    },
                    "label_anchor": label_anchor,
                    "capital_name": capital_name,
                    "capital_coord": capital_coord,
                    "importance": _compute_importance(shape_record, field_index),
                    "has_simulation_data": country_id in simulation_ids,
                    "is_disputed": record[field_index["TYPE"]] in {"Disputed", "Indeterminate"},
                }
        finally:
            countries_reader.close()
            capitals_reader.close()

    output = {
        "metadata": {
            "source": "Natural Earth Admin 0 Countries 1:50m + Natural Earth Populated Places 10m",
            "countries_url": COUNTRIES_URL,
            "capitals_url": PLACES_URL,
            "scale": SCALE,
        },
        "countries": dict(sorted(countries_output.items())),
    }

    OUTPUT_PATH.write_text(json.dumps(output, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Wrote {len(countries_output)} countries to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
