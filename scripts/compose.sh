#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="${RUNTIME_DIR:-$ROOT/runtime}"
PORTOLAN_VERSION="${PORTOLAN_VERSION:-0.4.1}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-sotm2026-gscloud-portolan}"
COMPOSE_FILE="$RUNTIME_DIR/compose.yml"
OVERRIDE_FILE="$ROOT/compose.portolan.yml"
export PORTOLAN_CLOUD_ZIP="$RUNTIME_DIR/geoserver-portolan-${PORTOLAN_VERSION}-cloud.zip"

if [[ ! -f "$COMPOSE_FILE" || ! -f "$PORTOLAN_CLOUD_ZIP" ]]; then
  echo "Ejecute make download primero." >&2
  exit 1
fi

exec docker compose \
  --project-directory "$ROOT" \
  --project-name "$PROJECT_NAME" \
  --file "$COMPOSE_FILE" \
  --file "$OVERRIDE_FILE" \
  "$@"
