SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

.PHONY: help download up setup verify query map viewer ps logs down reset test

help: ## Muestra los comandos disponibles.
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

download: ## Descarga el Compose oficial y el ZIP de geoserver-portolan.
	@./scripts/download.sh

up: download ## Inicia GeoServer Cloud 3.0.2 con geoserver-portolan.
	@./scripts/compose.sh up --detach
	@./scripts/compose.sh ps

setup: up ## Crea el workspace, datastore y capa OSM limitada a CDMX.
	@./scripts/create-osm-store.sh

verify: ## Comprueba versiones, plugin, datastore y consulta WFS.
	@./scripts/verify.sh

query: ## Guarda diez objetos OSM del BBOX en osm-cdmx.json.
	@curl --fail --silent --show-error --get \
		--data-urlencode 'service=WFS' \
		--data-urlencode 'version=2.0.0' \
		--data-urlencode 'request=GetFeature' \
		--data-urlencode 'typeNames=osm:planet-latest.osm' \
		--data-urlencode 'bbox=-99.137,19.429,-99.129,19.437,EPSG:4326' \
		--data-urlencode 'count=10' \
		--data-urlencode 'outputFormat=application/json' \
		'http://localhost:9090/geoserver/cloud/osm/wfs' -o osm-cdmx.json
	@echo 'Escribi osm-cdmx.json'

map: ## Guarda una imagen WMS del BBOX en osm-cdmx.png.
	@curl --fail --silent --show-error --get \
		--data-urlencode 'service=WMS' \
		--data-urlencode 'version=1.1.1' \
		--data-urlencode 'request=GetMap' \
		--data-urlencode 'layers=osm:planet-latest.osm' \
		--data-urlencode 'bbox=-99.137,19.429,-99.129,19.437' \
		--data-urlencode 'srs=EPSG:4326' \
		--data-urlencode 'width=900' \
		--data-urlencode 'height=900' \
		--data-urlencode 'format=image/png' \
		'http://localhost:9090/geoserver/cloud/osm/wms' -o osm-cdmx.png
	@echo 'Escribi osm-cdmx.png'

viewer: ## Muestra la URL del visor WFS con BBOX y CQL.
	@echo 'http://localhost:9080/'

ps: ## Muestra el estado de los contenedores.
	@./scripts/compose.sh ps

logs: ## Sigue los logs de GeoServer y del instalador del plugin.
	@./scripts/compose.sh logs --follow webui wms wfs restconfig portolan-libs-init

down: ## Detiene el POC y conserva los volumenes.
	@./scripts/compose.sh down --remove-orphans

reset: ## Elimina contenedores y volumenes del POC.
	@./scripts/compose.sh down --volumes --remove-orphans

test: ## Ejecuta comprobaciones estaticas del POC.
	@./tests/test-poc.sh
