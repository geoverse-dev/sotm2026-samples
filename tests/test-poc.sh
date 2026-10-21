#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || fail "$file does not contain: $text"
}

bash -n "$ROOT/scripts/download.sh"
bash -n "$ROOT/scripts/compose.sh"
bash -n "$ROOT/scripts/create-osm-store.sh"
bash -n "$ROOT/scripts/verify.sh"

assert_contains "$ROOT/scripts/download.sh" 'GSCLOUD_VERSION="${GSCLOUD_VERSION:-3.0.2}"'
assert_contains "$ROOT/scripts/download.sh" 'PORTOLAN_VERSION="${PORTOLAN_VERSION:-0.4.1}"'
assert_contains "$ROOT/scripts/download.sh" 'd614c450474e542ccc615aa70bfb2607c08b9458c1010177a12dab334e8634a7'

assert_contains "$ROOT/scripts/create-osm-store.sh" 'https://download.openplanetdata.com/osm/planet/geoparquet/v1/planet-latest.osm.parquet'
assert_contains "$ROOT/scripts/create-osm-store.sh" '<minx>-99.137</minx>'
assert_contains "$ROOT/scripts/create-osm-store.sh" '<maxx>-99.129</maxx>'
assert_contains "$ROOT/scripts/create-osm-store.sh" '<miny>19.429</miny>'
assert_contains "$ROOT/scripts/create-osm-store.sh" '<maxy>19.437</maxy>'
assert_contains "$ROOT/scripts/create-osm-store.sh" '<entry key="storage.provider">http</entry>'
assert_contains "$ROOT/scripts/create-osm-store.sh" 'overture-buildings-argentina'
assert_contains "$ROOT/scripts/create-osm-store.sh" 'tandil-c-hilbert-rg16k.parquet'
assert_contains "$ROOT/scripts/create-osm-store.sh" 'osm-cdmx-hilbert-rg16k.parquet'
assert_contains "$ROOT/scripts/create-osm-store.sh" 'MEXICO_LAYER="${MEXICO_LAYER:-osm-mexico-df}"'
assert_contains "$ROOT/scripts/create-osm-store.sh" '<name>$TANDIL_LAYER</name>'

assert_contains "$ROOT/compose.portolan.yml" 'portolan_additional_libs:/opt/additional_libs:ro'
assert_contains "$ROOT/compose.portolan.yml" 'osm-viewer:'
assert_contains "$ROOT/compose.portolan.yml" 'nginx:1.29.3-alpine'
assert_contains "$ROOT/viewer/app.js" 'CQL_FILTER'
assert_contains "$ROOT/viewer/app.js" 'MAX_AREA_KM2 = 1'
assert_contains "$ROOT/viewer/app.js" 'osm:osm-tandil'
assert_contains "$ROOT/viewer/app.js" 'osm:osm-mexico-df'
assert_contains "$ROOT/viewer/app.js" 'overture:overture-buildings-argentina'
assert_contains "$ROOT/viewer/app.js" 'BBOX(geometry,'
for service in webui wms wfs wcs wps restconfig gwc; do
  assert_contains "$ROOT/compose.portolan.yml" "  $service:"
done

assert_contains "$ROOT/README.md" 'overture-portolan'
assert_contains "$ROOT/README.md" 'no se puede aprovisionar el 2026-10-21'
assert_contains "$ROOT/README.md" 'make setup'
assert_contains "$ROOT/README.md" '0,75 km'

echo "Static POC checks passed."
