#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="${RUNTIME_DIR:-$ROOT/runtime}"
GSCLOUD_VERSION="${GSCLOUD_VERSION:-3.0.2}"
PORTOLAN_VERSION="${PORTOLAN_VERSION:-0.4.1}"
GSCLOUD_COMPOSE_URL="${GSCLOUD_COMPOSE_URL:-https://geoserver.org/geoserver-cloud/deploy/docker-compose/stable/pgconfig/compose.yml}"
PORTOLAN_CLOUD_URL="${PORTOLAN_CLOUD_URL:-https://github.com/jemacchi/geoserver-portolan/releases/download/v${PORTOLAN_VERSION}/geoserver-portolan-${PORTOLAN_VERSION}-cloud.zip}"
PORTOLAN_SHA256="${PORTOLAN_SHA256:-d614c450474e542ccc615aa70bfb2607c08b9458c1010177a12dab334e8634a7}"

download() {
  local url="$1"
  local destination="$2"
  local temporary="${destination}.tmp"
  curl --fail --location --retry 3 --show-error "$url" --output "$temporary"
  mv "$temporary" "$destination"
}

command -v curl >/dev/null || { echo "Falta curl." >&2; exit 1; }
command -v sha256sum >/dev/null || { echo "Falta sha256sum." >&2; exit 1; }
mkdir -p "$RUNTIME_DIR"

compose_file="$RUNTIME_DIR/compose.yml"
plugin_zip="$RUNTIME_DIR/geoserver-portolan-${PORTOLAN_VERSION}-cloud.zip"

if [[ ! -f "$compose_file" ]]; then
  echo "Descargando el Compose estable de GeoServer Cloud..."
  download "$GSCLOUD_COMPOSE_URL" "$compose_file"
fi

cloud_images=(config gateway webui wfs wms wcs wps rest gwc)
for image in "${cloud_images[@]}"; do
  grep -Fq "geoservercloud/geoserver-cloud-${image}:${GSCLOUD_VERSION}" "$compose_file" || {
    echo "El Compose descargado no fija geoserver-cloud-${image}:${GSCLOUD_VERSION}." >&2
    echo "Elimine $compose_file y revise GSCLOUD_COMPOSE_URL." >&2
    exit 1
  }
done

if [[ ! -f "$plugin_zip" ]]; then
  echo "Descargando geoserver-portolan ${PORTOLAN_VERSION}..."
  download "$PORTOLAN_CLOUD_URL" "$plugin_zip"
fi

echo "$PORTOLAN_SHA256  $plugin_zip" | sha256sum --check --status || {
  echo "El checksum del ZIP de geoserver-portolan no coincide." >&2
  exit 1
}

echo "Descargas verificadas en $RUNTIME_DIR"
