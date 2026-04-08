from __future__ import annotations

import json
import math
import re
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
COUNTRIES_OUTPUT_PATH = DATA_DIR / "map_countries.json"
SITES_OUTPUT_PATH = DATA_DIR / "map_sites.json"

COUNTRIES_URL = "https://naciscdn.org/naturalearth/50m/cultural/ne_50m_admin_0_countries.zip"
PLACES_URL = "https://naciscdn.org/naturalearth/10m/cultural/ne_10m_populated_places.zip"

SCALE = 10.0
WORLD_WIDTH = 360.0 * SCALE
HALF_WIDTH = WORLD_WIDTH / 2.0

MAX_NON_CAPITAL_SITES_PER_COUNTRY = 4
MAX_NON_CAPITAL_SITES_GLOBAL = 120

CAPITAL_PRIORITY = {
    "Admin-0 capital": 3,
    "Admin-0 capital alt": 2,
    "Admin-0 region capital": 1,
}

CITY_PRIORITY = {
    "worldcity": 3,
    "megacity": 2,
    "scalerank": 1,
}

MANUAL_CAPITALS = {
    "CYN": {"name": "North Nicosia", "lon": 33.3667, "lat": 35.1833, "population_est": 0.0},
    "GGY": {"name": "Saint Peter Port", "lon": -2.5369, "lat": 49.4550, "population_est": 0.0},
    "JEY": {"name": "Saint Helier", "lon": -2.1049, "lat": 49.1868, "population_est": 0.0},
    "NRU": {"name": "Yaren District", "lon": 166.9209, "lat": -0.5477, "population_est": 0.0},
    "SDS": {"name": "Juba", "lon": 31.5825, "lat": 4.8594, "population_est": 0.0},
    "SXM": {"name": "Philipsburg", "lon": -63.0538, "lat": 18.0260, "population_est": 0.0},
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


def _clean_text(value: object) -> str:
    text = " ".join(str(value or "").split())
    return text.strip()


def _slugify(value: object) -> str:
    text = _clean_text(value).lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")


def _is_valid_code(value: object) -> bool:
    text = _clean_text(value)
    return len(text) == 3 and text != "-99"


def _wrap_world_x(value: float) -> float:
    return ((value + HALF_WIDTH) % WORLD_WIDTH) - HALF_WIDTH


def _wrap_near(value: float, reference: float) -> float:
    candidates = [value - WORLD_WIDTH, value, value + WORLD_WIDTH]
    return min(candidates, key=lambda candidate: abs(candidate - reference))


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


def _compute_country_importance(record: shapefile.ShapeRecord, field_index: dict[str, int]) -> float:
    labelrank = float(record.record[field_index["LABELRANK"]] or 8.0)
    scalerank = float(record.record[field_index["scalerank"]] or 10.0)
    pop_est = max(float(record.record[field_index["POP_EST"]] or 0.0), 0.0)

    label_component = max(0.0, 1.0 - ((labelrank - 1.0) / 7.0))
    scale_component = max(0.0, 1.0 - ((scalerank - 1.0) / 9.0))
    pop_component = min(math.log10(pop_est + 1.0) / 10.0, 1.0)

    importance = (label_component * 0.55) + (scale_component * 0.25) + (pop_component * 0.20)
    return _round(max(0.05, min(importance, 1.0)))


def _compute_site_importance(priority_score: int, scalerank: float, population_est: float) -> float:
    scalerank_component = max(0.0, 1.0 - ((scalerank - 1.0) / 9.0))
    pop_component = min(math.log10(max(population_est, 0.0) + 1.0) / 8.0, 1.0)
    priority_component = min(priority_score / 3.0, 1.0)

    importance = (priority_component * 0.45) + (scalerank_component * 0.25) + (pop_component * 0.30)
    return _round(max(0.15, min(importance, 1.0)))


def _get_field_map(reader: shapefile.Reader) -> dict[str, int]:
    field_names = [field[0] for field in reader.fields[1:]]
    return {name: index for index, name in enumerate(field_names)}


def _resolve_country_id(raw_code: object, alias_map: dict[str, str]) -> str | None:
    code = _clean_text(raw_code)
    if not code:
        return None
    return alias_map.get(code)


def _build_capital_index(reader: shapefile.Reader, alias_map: dict[str, str]) -> dict[str, dict[str, float | str]]:
    field_index = _get_field_map(reader)
    capitals: dict[str, tuple[tuple[int, float, int], dict[str, float | str]]] = {}

    for shape_record in reader.iterShapeRecords():
        feature_class = shape_record.record[field_index["FEATURECLA"]]
        if feature_class not in CAPITAL_PRIORITY:
            continue

        country_id = _resolve_country_id(shape_record.record[field_index["ADM0_A3"]], alias_map)
        if country_id is None:
            continue

        population_est = float(shape_record.record[field_index.get("POP_MAX", 0)] or 0.0)
        score = (
            CAPITAL_PRIORITY[feature_class],
            population_est,
            -int(shape_record.record[field_index.get("LABELRANK", 0)] or 99),
        )
        candidate = {
            "name": _clean_text(shape_record.record[field_index["NAME"]]),
            "lon": float(shape_record.record[field_index["LONGITUDE"]]),
            "lat": float(shape_record.record[field_index["LATITUDE"]]),
            "population_est": population_est,
        }

        current = capitals.get(country_id)
        if current is None or score > current[0]:
            capitals[country_id] = (score, candidate)

    capital_index = {country_id: data for country_id, (_, data) in capitals.items()}
    capital_index.update(MANUAL_CAPITALS)
    return capital_index


def _build_country_outputs(
    countries_reader: shapefile.Reader,
    simulation_ids: set[str],
) -> tuple[dict[str, dict[str, object]], dict[str, str], dict[str, dict[str, object]]]:
    field_index = _get_field_map(countries_reader)
    countries_output: dict[str, dict[str, object]] = {}
    alias_map: dict[str, str] = {}
    country_runtime_meta: dict[str, dict[str, object]] = {}

    for shape_record in countries_reader.iterShapeRecords():
        record = shape_record.record
        geometry = shape_record.shape.__geo_interface__
        geometry_type = geometry["type"]
        if geometry_type not in {"Polygon", "MultiPolygon"}:
            continue

        country_id = _clean_text(record[field_index["ADM0_A3"]])
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

        population_est = float(record[field_index["POP_EST"]] or 0.0)
        gdp_est = float(record[field_index["GDP_MD"]] or 0.0) * 1_000_000.0
        gdp_per_capita_est = gdp_est / population_est if population_est > 0.0 else 0.0

        bbox_height = _round(max(shifted_ys) - min(shifted_ys))
        bbox_top_left_x = _round(_wrap_world_x(bbox_center_x - (bbox_width * 0.5)))
        bbox_top_left_y = _round(min(shifted_ys))

        iso_a2 = _clean_text(record[field_index["ISO_A2"]])
        iso_a3 = _clean_text(record[field_index["ISO_A3"]])
        region_un = _clean_text(record[field_index["REGION_UN"]])
        subregion = _clean_text(record[field_index["SUBREGION"]])

        countries_output[country_id] = {
            "id": country_id,
            "display_name": display_name,
            "iso_a2": iso_a2,
            "polygons": shifted_polygons,
            "bbox": {
                "position": [bbox_top_left_x, bbox_top_left_y],
                "size": [bbox_width, bbox_height],
                "center": [_round(bbox_center_x), _round((min(shifted_ys) + max(shifted_ys)) * 0.5)],
            },
            "label_anchor": label_anchor,
            "capital_name": "",
            "capital_coord": [],
            "importance": _compute_country_importance(shape_record, field_index),
            "has_simulation_data": country_id in simulation_ids,
            "is_disputed": _clean_text(record[field_index["TYPE"]]) in {"Disputed", "Indeterminate"},
            "population_est": int(round(population_est)),
            "gdp_est": int(round(gdp_est)),
            "gdp_per_capita_est": _round(gdp_per_capita_est),
            "region_un": region_un,
            "subregion": subregion,
            "economy_group": _clean_text(record[field_index["ECONOMY"]]),
            "income_group": _clean_text(record[field_index["INCOME_GRP"]]),
        }

        country_runtime_meta[country_id] = {
            "bbox_center_x": bbox_center_x,
            "display_name": display_name,
        }

        for alias_field in ("ADM0_A3", "ISO_A3", "SOV_A3", "GU_A3", "SU_A3", "BRK_A3"):
            alias_value = record[field_index.get(alias_field, 0)]
            if _is_valid_code(alias_value):
                alias_map[_clean_text(alias_value)] = country_id
        alias_map[country_id] = country_id

    return countries_output, alias_map, country_runtime_meta


def _apply_capitals(
    countries_output: dict[str, dict[str, object]],
    country_runtime_meta: dict[str, dict[str, object]],
    capital_index: dict[str, dict[str, float | str]],
) -> None:
    for country_id, country in countries_output.items():
        capital = capital_index.get(country_id)
        if capital is None:
            continue

        bbox_center_x = float(country_runtime_meta[country_id]["bbox_center_x"])
        capital_coord = _project_point(float(capital["lon"]), float(capital["lat"]))
        capital_coord[0] = _round(_wrap_near(capital_coord[0], bbox_center_x))

        country["capital_name"] = _clean_text(capital["name"])
        country["capital_coord"] = capital_coord


def _build_city_sites(
    places_reader: shapefile.Reader,
    countries_output: dict[str, dict[str, object]],
    alias_map: dict[str, str],
    capital_index: dict[str, dict[str, float | str]],
    country_runtime_meta: dict[str, dict[str, object]],
) -> list[dict[str, object]]:
    field_index = _get_field_map(places_reader)
    candidates: list[dict[str, object]] = []
    capital_name_index = {
        country_id: _slugify(capital["name"])
        for country_id, capital in capital_index.items()
        if _clean_text(capital.get("name", ""))
    }

    for shape_record in places_reader.iterShapeRecords():
        raw_country_id = shape_record.record[field_index["ADM0_A3"]]
        country_id = _resolve_country_id(raw_country_id, alias_map)
        if country_id is None or country_id not in countries_output:
            continue

        is_worldcity = int(shape_record.record[field_index.get("WORLDCITY", 0)] or 0) == 1
        is_megacity = int(shape_record.record[field_index.get("MEGACITY", 0)] or 0) == 1
        scalerank = float(shape_record.record[field_index["SCALERANK"]] or 99.0)
        if not (is_worldcity or is_megacity or scalerank <= 2.0):
            continue

        city_name = _clean_text(shape_record.record[field_index["NAME"]])
        if not city_name:
            continue

        if _slugify(city_name) == capital_name_index.get(country_id):
            continue

        population_est = float(shape_record.record[field_index.get("POP_MAX", 0)] or 0.0)
        priority_score = 0
        if is_worldcity:
            priority_score = CITY_PRIORITY["worldcity"]
        elif is_megacity:
            priority_score = CITY_PRIORITY["megacity"]
        else:
            priority_score = CITY_PRIORITY["scalerank"]

        bbox_center_x = float(country_runtime_meta[country_id]["bbox_center_x"])
        coord = _project_point(
            float(shape_record.record[field_index["LONGITUDE"]]),
            float(shape_record.record[field_index["LATITUDE"]]),
        )
        coord[0] = _round(_wrap_near(coord[0], bbox_center_x))

        candidates.append(
            {
                "id": "%s-%s" % (country_id.lower(), _slugify(city_name)),
                "country_id": country_id,
                "name": city_name,
                "type": "city",
                "coord": coord,
                "population_est": int(round(population_est)),
                "importance": _compute_site_importance(priority_score, scalerank, population_est),
                "_score": (
                    priority_score,
                    population_est,
                    countries_output[country_id]["importance"],
                ),
            }
        )

    candidates.sort(
        key=lambda item: (
            item["_score"][0],
            item["_score"][1],
            item["_score"][2],
            item["name"],
        ),
        reverse=True,
    )

    selected: list[dict[str, object]] = []
    per_country_counts: dict[str, int] = {}
    total_count = 0
    used_keys: set[tuple[str, str]] = set()

    for candidate in candidates:
        if total_count >= MAX_NON_CAPITAL_SITES_GLOBAL:
            break

        country_id = str(candidate["country_id"])
        if per_country_counts.get(country_id, 0) >= MAX_NON_CAPITAL_SITES_PER_COUNTRY:
            continue

        dedupe_key = (country_id, _slugify(candidate["name"]))
        if dedupe_key in used_keys:
            continue

        used_keys.add(dedupe_key)
        per_country_counts[country_id] = per_country_counts.get(country_id, 0) + 1
        total_count += 1

        selected.append(
            {
                "id": candidate["id"],
                "country_id": country_id,
                "name": candidate["name"],
                "type": candidate["type"],
                "coord": candidate["coord"],
                "population_est": candidate["population_est"],
                "importance": candidate["importance"],
            }
        )

    return selected


def _build_capital_sites(
    countries_output: dict[str, dict[str, object]],
    capital_index: dict[str, dict[str, float | str]],
) -> list[dict[str, object]]:
    sites: list[dict[str, object]] = []
    for country_id, country in countries_output.items():
        capital_name = _clean_text(country.get("capital_name", ""))
        capital_coord = country.get("capital_coord", [])
        if not capital_name or not capital_coord:
            continue

        capital_population = int(round(float(capital_index.get(country_id, {}).get("population_est", 0.0) or 0.0)))
        sites.append(
            {
                "id": "%s-capital" % country_id.lower(),
                "country_id": country_id,
                "name": capital_name,
                "type": "capital",
                "coord": capital_coord,
                "population_est": capital_population,
                "importance": _round(max(float(country.get("importance", 0.5)), 0.65)),
            }
        )
    return sites


def main() -> None:
    simulation_data = json.loads((DATA_DIR / "countries.json").read_text(encoding="utf-8"))
    simulation_ids = set(simulation_data.keys())

    with tempfile.TemporaryDirectory() as temp_dir_raw:
        temp_dir = Path(temp_dir_raw)
        countries_dir = _download_and_extract(COUNTRIES_URL, temp_dir)
        places_dir = _download_and_extract(PLACES_URL, temp_dir)

        countries_reader = _reader_for(countries_dir)
        places_reader = _reader_for(places_dir)
        try:
            countries_output, alias_map, country_runtime_meta = _build_country_outputs(countries_reader, simulation_ids)
            capital_index = _build_capital_index(places_reader, alias_map)
            _apply_capitals(countries_output, country_runtime_meta, capital_index)

            places_reader.close()
            places_reader = _reader_for(places_dir)

            capital_sites = _build_capital_sites(countries_output, capital_index)
            city_sites = _build_city_sites(
                places_reader,
                countries_output,
                alias_map,
                capital_index,
                country_runtime_meta,
            )
        finally:
            countries_reader.close()
            places_reader.close()

    countries_payload = {
        "metadata": {
            "source": "Natural Earth Admin 0 Countries 1:50m + Natural Earth Populated Places 10m",
            "countries_url": COUNTRIES_URL,
            "places_url": PLACES_URL,
            "scale": SCALE,
        },
        "countries": dict(sorted(countries_output.items())),
    }

    sites_payload = {
        "metadata": {
            "source": "Natural Earth Populated Places 10m",
            "places_url": PLACES_URL,
            "capital_sites": len(capital_sites),
            "city_sites": len(city_sites),
            "max_non_capital_sites_per_country": MAX_NON_CAPITAL_SITES_PER_COUNTRY,
            "max_non_capital_sites_global": MAX_NON_CAPITAL_SITES_GLOBAL,
        },
        "sites": capital_sites + city_sites,
    }

    COUNTRIES_OUTPUT_PATH.write_text(
        json.dumps(countries_payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    SITES_OUTPUT_PATH.write_text(
        json.dumps(sites_payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"Wrote {len(countries_output)} countries to {COUNTRIES_OUTPUT_PATH}")
    print(f"Wrote {len(capital_sites) + len(city_sites)} sites to {SITES_OUTPUT_PATH}")


if __name__ == "__main__":
    main()
