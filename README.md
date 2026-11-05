# GeoServer Cloud, Portolan, and OSM for State of the Map Latam 2026

[Leer en español](README.es.md)

These implementation examples accompany the
[State of the Map Latam 2026 presentation in Mexico](https://docs.google.com/presentation/d/1_skR7xCnRK1H0vKgzNxQLTRYxppRDbPM).

This collection of implementation examples starts GeoServer Cloud 3.0.2 and adds
`geoserver-portolan` 0.4.1. It also publishes four remote GeoParquet datasets as
queryable layers:

- The OpenStreetMap planet dataset from OpenPlanetData.
- Overture buildings in Argentina.
- An optimized OpenStreetMap extract for Tandil.
- An optimized OpenStreetMap extract for Mexico City.

The examples install the two components required by the demonstration:

- `geoserver-portolan` integrates Portolan catalogs with GeoServer Cloud.
- The Parquet datastore queries the OpenPlanetData planet GeoParquet over HTTP.

The implementation does not download the planet file. The remote file is more
than 200 GB; GeoServer uses HTTP range requests to read only the required blocks.

## Requirements

Install the following tools:

- Docker with the Compose plugin.
- `curl`.
- GNU Make.
- `sha256sum`.

Allocate at least 10 GB of memory to Docker. The Compose setup starts several services.

## Quick start

Run:

```bash
make setup
make verify
```

`make setup` performs the following tasks:

1. Downloads the official stable GeoServer Cloud Compose file.
2. Checks that all its images use version 3.0.2.
3. Downloads and verifies the `cloud` ZIP for `geoserver-portolan` 0.4.1.
4. Starts the services with Docker Compose.
5. Creates the `osm` workspace.
6. Creates the `openplanetdata` Parquet datastore.
7. Publishes the `osm:planet-latest.osm` layer.
8. Creates `overture-buildings-argentina` and publishes its buildings layer.
9. Creates `osm-tandil` and publishes the optimized Tandil layer.
10. Creates `osm-mexico-df` and publishes the optimized Mexico City layer.

Open <http://localhost:9090/geoserver/cloud/web/>.
Use `admin` as the username and `geoserver` as the password.

The first startup takes several minutes because Docker must download all images.

## OpenStreetMap demonstration

The datastore points to this remote file:

```text
https://download.openplanetdata.com/osm/planet/geoparquet/v1/planet-latest.osm.parquet
```

There is no local copy of the file. The source supports HTTP range requests.

The layer declares this BBOX in EPSG:4326:

```text
-99.137,19.429,-99.129,19.437
```

The window covers approximately 0.75 km² in Mexico City's Historic Center. The
preview uses that extent and avoids an initial query against the entire planet.

Instead of the WMS preview, open the WFS client:

```text
http://localhost:9080/
```

The client uses OpenLayers 10.11.0 and requests GeoJSON from WFS 1.0.0. Its selector
can use `osm-mexico-df`, `osm-tandil`, or `overture-buildings-argentina`. The viewer
opens `osm-mexico-df` as the initial layer. The query combines the BBOX with an
optional CQL filter. The browser rejects any BBOX larger than 1 km² before calling
GeoServer. The initial limit is 50 features and the maximum allowed value is 500.

Click **Use current view** to copy the visible window into the BBOX fields. Click
**Query WFS** to run the query and draw the response. The viewer also displays the
full URL to make the demonstration easier.

The base map uses OpenStreetMap tiles. Nginx serves the client and proxies
`/geoserver/` to the gateway inside Docker, so the browser does not require
additional CORS permissions.

You can also test WFS and WMS from the terminal:

```bash
make query
make map
```

The first command creates `osm-cdmx.json` with ten features. The second creates
`osm-cdmx.png` with a WMS image.

The BBOX configures the layer's default extent; it is not an access restriction.
A WFS query with a different filter can still request features outside that window.

## Optimized GeoParquet datasets for Argentina

The `overture-buildings-argentina` datastore points to `optimized-v2.0.parquet`.
It publishes `overture:overture-buildings-argentina` using the native table
`optimized-v2.0`. The file contains 26,765,980 Overture building polygons. The
initial view uses a window smaller than 1 km² in Buenos Aires.

The `osm-tandil` datastore points to `tandil-c-hilbert-rg16k.parquet`. It publishes
`osm:osm-tandil` using the native table `tandil-c-hilbert-rg16k`. The file contains
41,609 OSM features and three row groups. The initial view uses a window smaller
than 1 km² in central Tandil.

The `osm-mexico-df` datastore points to `osm-cdmx-hilbert-rg16k.parquet`. It
publishes `osm:osm-mexico-df` using the native table `osm-cdmx-hilbert-rg16k`.
The file contains 625,701 OSM features distributed across 39 row groups. The viewer
uses this layer instead of the planet GeoParquet. The initial view uses a 0.75 km²
window in Mexico City.

Both datastores read the remote files through HTTP range requests.

## Status of the Overture catalog in Portolan

Open **Utilities > Portolan** after signing in. The page should show
`Parquet (Parquetry)` as available.

The registry contains `overture-portolan` and resolves it to this catalog:

```text
https://nlebovits.github.io/overture-portolan/catalog.json
```

That catalog cannot be provisioned as of 2026-10-21. Its assets point to Overture
release `2026-08-19.0`, which is no longer published. GeoServer creates partial
datastores but cannot discover feature types or create layers.

The logs show `no files found` errors for GeoParquet and HTTP 404 responses for
PMTiles. This implementation does not modify or mirror the catalog to hide the
problem. Do not select **Provision selected catalog** until its publisher updates it.

Portolan is a specification and toolset for publishing geospatial data at any
scale. The plugin interprets the catalog and delegates GeoParquet and PMTiles
reading to the datastores installed in GeoServer Cloud.

## Commands

```text
make download  downloads and verifies the published files
make up        starts the Compose setup
make setup     starts Compose and publishes the OSM layer
make verify    checks the versions, plugin, and WFS
make query     runs a bounded WFS query
make map       runs a bounded WMS request
make viewer    displays the OpenLayers client URL
make ps        displays service status
make logs      follows the main logs
make down      stops the services and preserves the data
make reset     removes the containers and volumes for these examples
make test      validates the scripts and pinned values
```

`make setup` is idempotent. You can run it again without duplicating resources.

## Downloaded files

The ignored `runtime/` directory contains:

```text
runtime/compose.yml
runtime/geoserver-portolan-0.4.1-cloud.zip
```

The script verifies the plugin ZIP's SHA-256 checksum. It also rejects a Compose
file that does not use GeoServer Cloud 3.0.2.

You can use a mirror with environment variables:

```bash
GSCLOUD_COMPOSE_URL=https://example.org/compose.yml \
PORTOLAN_CLOUD_URL=https://example.org/geoserver-portolan-0.4.1-cloud.zip \
make download
```

Keep the same content or set `PORTOLAN_SHA256` to the expected checksum.

## Troubleshooting

Check the status and logs:

```bash
make ps
make logs
```

If you changed versions or a catalog remains from an earlier test, restart everything:

```bash
make reset
make setup
```

`make reset` removes the volumes for these examples. It does not affect other
Compose projects.

If the remote query is slow, confirm that your network allows HTTP range requests
to `download.openplanetdata.com`. The script uses a 30-second timeout.

## Sources

- [GeoServer Cloud 3.0.2](https://github.com/geoserver/geoserver-cloud/releases/tag/v3.0.2)
- [Parquet datastore REST guide](https://geoserver.org/geoserver-cloud/user-guide/geoparquet-rest-api/)
- [geoserver-portolan 0.4.1 release](https://github.com/jemacchi/geoserver-portolan/releases/tag/v0.4.1)
- [OpenStreetMap on OpenPlanetData](https://openplanetdata.com/datasets/openstreetmap/)
- [Portolan](https://www.portolan-sdi.org/)
