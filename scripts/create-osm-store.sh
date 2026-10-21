#!/usr/bin/env bash
set -Eeuo pipefail

GEOSERVER_URL="${GEOSERVER_URL:-http://localhost:9090/geoserver/cloud}"
REST="$GEOSERVER_URL/rest"
AUTH="${GEOSERVER_AUTH:-admin:geoserver}"
WORKSPACE="${OSM_WORKSPACE:-osm}"
OVERTURE_WORKSPACE="${OVERTURE_WORKSPACE:-overture}"
STORE="${OSM_STORE:-openplanetdata}"
NATIVE_NAME="${OSM_NATIVE_NAME:-planet-latest.osm}"
PARQUET_URL="${OSM_PARQUET_URL:-https://download.openplanetdata.com/osm/planet/geoparquet/v1/planet-latest.osm.parquet}"
OVERTURE_STORE="${OVERTURE_STORE:-overture-buildings-argentina}"
OVERTURE_NATIVE_NAME="${OVERTURE_NATIVE_NAME:-optimized-v2.0}"
OVERTURE_LAYER="${OVERTURE_LAYER:-overture-buildings-argentina}"
OVERTURE_PARQUET_URL="${OVERTURE_PARQUET_URL:-https://pub-f31f4e8d3c804f2bab542268b9915ad7.r2.dev/optimized-v2.0.parquet}"
TANDIL_STORE="${TANDIL_STORE:-osm-tandil}"
TANDIL_NATIVE_NAME="${TANDIL_NATIVE_NAME:-tandil-c-hilbert-rg16k}"
TANDIL_LAYER="${TANDIL_LAYER:-osm-tandil}"
TANDIL_PARQUET_URL="${TANDIL_PARQUET_URL:-https://pub-f31f4e8d3c804f2bab542268b9915ad7.r2.dev/tandil-c-hilbert-rg16k.parquet}"
MEXICO_STORE="${MEXICO_STORE:-osm-mexico-df}"
MEXICO_NATIVE_NAME="${MEXICO_NATIVE_NAME:-osm-cdmx-hilbert-rg16k}"
MEXICO_LAYER="${MEXICO_LAYER:-osm-mexico-df}"
MEXICO_PARQUET_URL="${MEXICO_PARQUET_URL:-https://pub-f31f4e8d3c804f2bab542268b9915ad7.r2.dev/osm-cdmx-hilbert-rg16k.parquet}"

request_status() {
  curl --silent --output /dev/null --write-out '%{http_code}' -u "$AUTH" "$1"
}

echo "Esperando la API REST de GeoServer Cloud..."
for _ in $(seq 1 90); do
  if [[ "$(request_status "$REST/workspaces.json" || true)" == "200" ]]; then
    break
  fi
  sleep 2
done
[[ "$(request_status "$REST/workspaces.json" || true)" == "200" ]] || {
  echo "GeoServer no quedo listo en $GEOSERVER_URL." >&2
  exit 1
}

if [[ "$(request_status "$REST/workspaces/$WORKSPACE.json")" == "404" ]]; then
  echo "Creando workspace $WORKSPACE..."
  curl --fail --silent --show-error -u "$AUTH" \
    -X POST -H 'Content-Type: text/xml' \
    -d "<workspace><name>$WORKSPACE</name></workspace>" \
    "$REST/workspaces"
fi


if [[ "$(request_status "$REST/workspaces/$OVERTURE_WORKSPACE.json")" == "404" ]]; then
  echo "Creando workspace $OVERTURE_WORKSPACE..."
  curl --fail --silent --show-error -u "$AUTH" \
    -X POST -H 'Content-Type: text/xml' \
    -d "<workspace><name>$OVERTURE_WORKSPACE</name></workspace>" \
    "$REST/workspaces"
fi
if [[ "$(request_status "$REST/workspaces/$WORKSPACE/datastores/$STORE.json")" == "404" ]]; then
  echo "Creando datastore Parquet remoto $STORE..."
  curl --fail --silent --show-error -u "$AUTH" \
    -X POST -H 'Content-Type: text/xml' -d @- \
    "$REST/workspaces/$WORKSPACE/datastores" <<EOF
<dataStore>
  <name>$STORE</name>
  <type>Parquet</type>
  <connectionParameters>
    <entry key="geoparquet">$PARQUET_URL</entry>
    <entry key="storage.provider">http</entry>
    <entry key="storage.http.timeout-millis">30000</entry>
  </connectionParameters>
</dataStore>
EOF
fi

if [[ "$(request_status "$REST/workspaces/$WORKSPACE/datastores/$STORE/featuretypes/$NATIVE_NAME.json")" == "404" ]]; then
  echo "Publicando $WORKSPACE:$NATIVE_NAME con la extension acotada a CDMX..."
  curl --fail --silent --show-error -u "$AUTH" \
    -X POST -H 'Content-Type: text/xml' -d @- \
    "$REST/workspaces/$WORKSPACE/datastores/$STORE/featuretypes" <<EOF
<featureType>
  <name>$NATIVE_NAME</name>
  <nativeName>$NATIVE_NAME</nativeName>
  <title>OpenStreetMap en el centro de Ciudad de Mexico</title>
  <abstract>Vista de demostracion sobre el GeoParquet planetario remoto de OpenPlanetData.</abstract>
  <srs>EPSG:4326</srs>
  <nativeBoundingBox>
    <minx>-99.137</minx>
    <maxx>-99.129</maxx>
    <miny>19.429</miny>
    <maxy>19.437</maxy>
    <crs>EPSG:4326</crs>
  </nativeBoundingBox>
  <latLonBoundingBox>
    <minx>-99.137</minx>
    <maxx>-99.129</maxx>
    <miny>19.429</miny>
    <maxy>19.437</maxy>
    <crs>EPSG:4326</crs>
  </latLonBoundingBox>
  <projectionPolicy>FORCE_DECLARED</projectionPolicy>
  <numDecimals>8</numDecimals>
  <enabled>true</enabled>
  <advertised>true</advertised>
</featureType>
EOF
fi

echo "Capa disponible: $WORKSPACE:$NATIVE_NAME"

if [[ "$(request_status "$REST/workspaces/$OVERTURE_WORKSPACE/datastores/$OVERTURE_STORE.json")" == "404" ]]; then
  echo "Creando datastore Parquet remoto $OVERTURE_STORE..."
  curl --fail --silent --show-error -u "$AUTH" \
    -X POST -H 'Content-Type: text/xml' -d @- \
    "$REST/workspaces/$OVERTURE_WORKSPACE/datastores" <<EOF_DATASTORE
<dataStore>
  <name>$OVERTURE_STORE</name>
  <type>Parquet</type>
  <connectionParameters>
    <entry key="geoparquet">$OVERTURE_PARQUET_URL</entry>
    <entry key="storage.provider">http</entry>
    <entry key="storage.http.timeout-millis">180000</entry>
  </connectionParameters>
</dataStore>
EOF_DATASTORE
fi

if [[ "$(request_status "$REST/workspaces/$OVERTURE_WORKSPACE/datastores/$OVERTURE_STORE/featuretypes/$OVERTURE_LAYER.json")" == "404" ]]; then
  echo "Publicando $OVERTURE_WORKSPACE:$OVERTURE_LAYER con una extension acotada en Buenos Aires..."
  curl --fail --silent --show-error -u "$AUTH" \
    -X POST -H 'Content-Type: text/xml' -d @- \
    "$REST/workspaces/$OVERTURE_WORKSPACE/datastores/$OVERTURE_STORE/featuretypes" <<EOF_LAYER
<featureType>
  <name>$OVERTURE_LAYER</name>
  <nativeName>$OVERTURE_NATIVE_NAME</nativeName>
  <title>Overture Buildings Argentina</title>
  <abstract>Edificios de Argentina desde un GeoParquet remoto optimizado. La fuente declarada por los registros es Microsoft ML Buildings.</abstract>
  <srs>EPSG:4326</srs>
  <nativeBoundingBox>
    <minx>-58.386</minx><maxx>-58.378</maxx>
    <miny>-34.607</miny><maxy>-34.599</maxy>
    <crs>EPSG:4326</crs>
  </nativeBoundingBox>
  <latLonBoundingBox>
    <minx>-58.386</minx><maxx>-58.378</maxx>
    <miny>-34.607</miny><maxy>-34.599</maxy>
    <crs>EPSG:4326</crs>
  </latLonBoundingBox>
  <projectionPolicy>FORCE_DECLARED</projectionPolicy>
  <numDecimals>8</numDecimals>
  <enabled>true</enabled><advertised>true</advertised>
</featureType>
EOF_LAYER
fi

echo "Capa disponible: $OVERTURE_WORKSPACE:$OVERTURE_LAYER"

if [[ "$(request_status "$REST/workspaces/$WORKSPACE/datastores/$TANDIL_STORE.json")" == "404" ]]; then
  echo "Creando datastore Parquet remoto $TANDIL_STORE..."
  curl --fail --silent --show-error -u "$AUTH" \
    -X POST -H 'Content-Type: text/xml' -d @- \
    "$REST/workspaces/$WORKSPACE/datastores" <<EOF_DATASTORE
<dataStore>
  <name>$TANDIL_STORE</name>
  <type>Parquet</type>
  <connectionParameters>
    <entry key="geoparquet">$TANDIL_PARQUET_URL</entry>
    <entry key="storage.provider">http</entry>
    <entry key="storage.http.timeout-millis">180000</entry>
  </connectionParameters>
</dataStore>
EOF_DATASTORE
fi

if [[ "$(request_status "$REST/workspaces/$WORKSPACE/datastores/$TANDIL_STORE/featuretypes/$TANDIL_LAYER.json")" == "404" ]]; then
  echo "Publicando $WORKSPACE:$TANDIL_LAYER con una extension acotada en Tandil..."
  curl --fail --silent --show-error -u "$AUTH" \
    -X POST -H 'Content-Type: text/xml' -d @- \
    "$REST/workspaces/$WORKSPACE/datastores/$TANDIL_STORE/featuretypes" <<EOF_LAYER
<featureType>
  <name>$TANDIL_LAYER</name>
  <nativeName>$TANDIL_NATIVE_NAME</nativeName>
  <title>OSM Tandil</title>
  <abstract>Objetos OpenStreetMap de Tandil desde un GeoParquet remoto con ordenamiento Hilbert.</abstract>
  <srs>EPSG:4326</srs>
  <nativeBoundingBox>
    <minx>-59.141</minx><maxx>-59.133</maxx>
    <miny>-37.322</miny><maxy>-37.314</maxy>
    <crs>EPSG:4326</crs>
  </nativeBoundingBox>
  <latLonBoundingBox>
    <minx>-59.141</minx><maxx>-59.133</maxx>
    <miny>-37.322</miny><maxy>-37.314</maxy>
    <crs>EPSG:4326</crs>
  </latLonBoundingBox>
  <projectionPolicy>FORCE_DECLARED</projectionPolicy>
  <numDecimals>8</numDecimals>
  <enabled>true</enabled><advertised>true</advertised>
</featureType>
EOF_LAYER
fi

echo "Capa disponible: $WORKSPACE:$TANDIL_LAYER"

if [[ "$(request_status "$REST/workspaces/$WORKSPACE/datastores/$MEXICO_STORE.json")" == "404" ]]; then
  echo "Creando datastore Parquet remoto $MEXICO_STORE..."
  curl --fail --silent --show-error -u "$AUTH" \
    -X POST -H 'Content-Type: text/xml' -d @- \
    "$REST/workspaces/$WORKSPACE/datastores" <<EOF_DATASTORE
<dataStore>
  <name>$MEXICO_STORE</name>
  <type>Parquet</type>
  <connectionParameters>
    <entry key="geoparquet">$MEXICO_PARQUET_URL</entry>
    <entry key="storage.provider">http</entry>
    <entry key="storage.http.timeout-millis">180000</entry>
  </connectionParameters>
</dataStore>
EOF_DATASTORE
fi

if [[ "$(request_status "$REST/workspaces/$WORKSPACE/datastores/$MEXICO_STORE/featuretypes/$MEXICO_LAYER.json")" == "404" ]]; then
  echo "Publicando $WORKSPACE:$MEXICO_LAYER con una extension acotada en Ciudad de Mexico..."
  curl --fail --silent --show-error -u "$AUTH" \
    -X POST -H 'Content-Type: text/xml' -d @- \
    "$REST/workspaces/$WORKSPACE/datastores/$MEXICO_STORE/featuretypes" <<EOF_LAYER
<featureType>
  <name>$MEXICO_LAYER</name>
  <nativeName>$MEXICO_NATIVE_NAME</nativeName>
  <title>OSM Ciudad de Mexico</title>
  <abstract>Objetos OpenStreetMap de Ciudad de Mexico desde un GeoParquet remoto con ordenamiento Hilbert.</abstract>
  <srs>EPSG:4326</srs>
  <nativeBoundingBox>
    <minx>-99.137</minx><maxx>-99.129</maxx>
    <miny>19.429</miny><maxy>19.437</maxy>
    <crs>EPSG:4326</crs>
  </nativeBoundingBox>
  <latLonBoundingBox>
    <minx>-99.137</minx><maxx>-99.129</maxx>
    <miny>19.429</miny><maxy>19.437</maxy>
    <crs>EPSG:4326</crs>
  </latLonBoundingBox>
  <projectionPolicy>FORCE_DECLARED</projectionPolicy>
  <numDecimals>8</numDecimals>
  <enabled>true</enabled><advertised>true</advertised>
</featureType>
EOF_LAYER
fi

echo "Capa disponible: $WORKSPACE:$MEXICO_LAYER"
echo "Vista previa: $GEOSERVER_URL/web/wicket/bookmarkable/org.geoserver.web.demo.MapPreviewPage"
