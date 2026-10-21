#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GEOSERVER_URL="${GEOSERVER_URL:-http://localhost:9090/geoserver/cloud}"
REST="$GEOSERVER_URL/rest"
AUTH="${GEOSERVER_AUTH:-admin:geoserver}"
WORKSPACE="${OSM_WORKSPACE:-osm}"
STORE="${OSM_STORE:-openplanetdata}"
LAYER="${OSM_NATIVE_NAME:-planet-latest.osm}"

"$ROOT/scripts/compose.sh" config --quiet

images="$($ROOT/scripts/compose.sh config --images)"
unexpected="$(printf '%s\n' "$images" | grep '^geoservercloud/geoserver-cloud-' | grep -v ':3.0.2$' || true)"
[[ -z "$unexpected" ]] || {
  echo "Se encontraron imagenes GeoServer Cloud distintas de 3.0.2:" >&2
  echo "$unexpected" >&2
  exit 1
}

store="$(curl --fail --silent --show-error -u "$AUTH" \
  "$REST/workspaces/$WORKSPACE/datastores/$STORE.json")"
grep -Fq 'https://download.openplanetdata.com/osm/planet/geoparquet/v1/planet-latest.osm.parquet' <<<"$store"
curl --fail --silent --show-error -u "$AUTH" \
  "$REST/workspaces/$WORKSPACE/datastores/$STORE/featuretypes/$LAYER.json" >/dev/null
response="$(curl --fail --silent --show-error --get \
  --data-urlencode 'service=WFS' \
  --data-urlencode 'version=2.0.0' \
  --data-urlencode 'request=GetFeature' \
  --data-urlencode "typeNames=$WORKSPACE:$LAYER" \
  --data-urlencode 'bbox=-99.137,19.429,-99.129,19.437,EPSG:4326' \
  --data-urlencode 'count=1' \
  --data-urlencode 'outputFormat=application/json' \
  "$GEOSERVER_URL/$WORKSPACE/wfs")"
grep -Fq 'FeatureCollection' <<<"$response"

curl --fail --silent --show-error -u "$AUTH" \
  "$REST/about/status/Parquetry+Plugin.json" >/dev/null
echo "OK: GeoServer Cloud 3.0.2, geoserver-portolan y la consulta OSM funcionan."
