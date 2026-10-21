# GeoServer Cloud, Portolan y OSM para State of the Map Latam 2026

Este POC inicia GeoServer Cloud 3.0.2 y agrega `geoserver-portolan` 0.4.1.
También publica tres GeoParquet remotos como capas consultables:

- El planeta OpenStreetMap de OpenPlanetData.
- Los edificios de Overture en Argentina.
- Una extracción optimizada de OpenStreetMap para Tandil.
- Una extracción optimizada de OpenStreetMap para Ciudad de México.

El POC instala las dos piezas que necesita la demostración:

- `geoserver-portolan` integra catálogos Portolan con GeoServer Cloud.
- El datastore Parquet consulta por HTTP el GeoParquet planetario de OpenPlanetData.

El POC no descarga el archivo planetario. El archivo remoto mide más de 200 GB.
GeoServer lee por rangos HTTP solo los bloques que necesita.

## Requisitos

Instala estas herramientas:

- Docker con el complemento Compose.
- `curl`.
- GNU Make.
- `sha256sum`.

Reserva al menos 10 GB de memoria para Docker. El Compose inicia varios servicios.

## Inicio rápido

Ejecuta:

```bash
make setup
make verify
```

`make setup` realiza estas tareas:

1. Descarga el Compose estable oficial de GeoServer Cloud.
2. Comprueba que todas sus imágenes usan la versión 3.0.2.
3. Descarga y verifica el ZIP `cloud` de `geoserver-portolan` 0.4.1.
4. Inicia los servicios con Docker Compose.
5. Crea el workspace `osm`.
6. Crea el datastore Parquet `openplanetdata`.
7. Publica la capa `osm:planet-latest.osm`.
8. Crea `overture-buildings-argentina` y publica su capa de edificios.
9. Crea `osm-tandil` y publica la capa optimizada de Tandil.
10. Crea `osm-mexico-df` y publica la capa optimizada de Ciudad de México.

Abre <http://localhost:9090/geoserver/cloud/web/>.
Usa `admin` como usuario y `geoserver` como contraseña.

El primer inicio tarda varios minutos. Docker debe descargar todas las imágenes.

## Demostración de OpenStreetMap

El datastore apunta a este archivo remoto:

```text
https://download.openplanetdata.com/osm/planet/geoparquet/v1/planet-latest.osm.parquet
```

No existe una copia local del archivo. La fuente admite solicitudes HTTP por rangos.

La capa declara este BBOX en EPSG:4326:

```text
-99.137,19.429,-99.129,19.437
```

La ventana cubre unos 0,75 km² del Centro Histórico de Ciudad de México.
La vista previa usa esa extensión y evita una consulta inicial al planeta completo.

En lugar de la vista previa WMS, abre el cliente WFS:

```text
http://localhost:9080/
```

El cliente usa OpenLayers 10.11.0 y pide GeoJSON a WFS 1.0.0.
El selector permite usar `osm-mexico-df`, `osm-tandil` u `overture-buildings-argentina`.
El visor abre `osm-mexico-df` como capa inicial.
La consulta combina el BBOX con un filtro CQL opcional.
El navegador rechaza cualquier BBOX mayor a 1 km² antes de llamar a GeoServer.
El límite inicial es de 50 objetos y el máximo permitido es de 500.

Pulsa **Usar vista actual** para copiar la ventana visible a los campos del BBOX.
Pulsa **Consultar WFS** para ejecutar la consulta y dibujar la respuesta.
El visor muestra también la URL completa para facilitar la demostración.

El mapa base usa teselas de OpenStreetMap.
Nginx sirve el cliente y envía `/geoserver/` al gateway dentro de Docker.
Así, el navegador no necesita permisos CORS adicionales.

También puedes probar WFS y WMS desde la terminal:

```bash
make query
make map
```

El primer comando crea `osm-cdmx.json` con diez objetos.
El segundo comando crea `osm-cdmx.png` con una imagen WMS.

El BBOX configura la extensión predeterminada de la capa. No es un límite de acceso.
Una consulta WFS con otro filtro todavía puede pedir objetos fuera de esa ventana.

## GeoParquet optimizados de Argentina

El datastore `overture-buildings-argentina` apunta a `optimized-v2.0.parquet`.
Publica `overture:overture-buildings-argentina` con la tabla nativa `optimized-v2.0`.
El archivo contiene 26.765.980 polígonos de edificios de Overture.
La vista inicial usa una ventana menor a 1 km² en Buenos Aires.

El datastore `osm-tandil` apunta a `tandil-c-hilbert-rg16k.parquet`.
Publica `osm:osm-tandil` con la tabla nativa `tandil-c-hilbert-rg16k`.
El archivo contiene 41.609 objetos OSM y tres row groups.
La vista inicial usa una ventana menor a 1 km² en el centro de Tandil.

El datastore `osm-mexico-df` apunta a `osm-cdmx-hilbert-rg16k.parquet`.
Publica `osm:osm-mexico-df` con la tabla nativa `osm-cdmx-hilbert-rg16k`.
El archivo contiene 625.701 objetos OSM distribuidos en 39 row groups.
El visor usa esta capa en lugar del GeoParquet planetario.
La vista inicial usa una ventana de 0,75 km² en Ciudad de México.

Ambos datastores leen los archivos remotos mediante solicitudes HTTP por rangos.


## Estado del catálogo Overture en Portolan

Abre **Utilities > Portolan** después de iniciar sesión.
La página debe mostrar `Parquet (Parquetry)` como disponible.

El registro contiene `overture-portolan` y lo resuelve a este catálogo:

```text
https://nlebovits.github.io/overture-portolan/catalog.json
```

Ese catálogo no se puede aprovisionar el 2026-10-21.
Sus activos apuntan al release Overture `2026-08-19.0`, que ya no está publicado.
GeoServer crea datastores parciales, pero no puede descubrir tipos ni crear capas.

Los logs muestran errores `no files found` para GeoParquet y HTTP 404 para PMTiles.
Este POC no modifica ni espeja el catálogo para ocultar ese problema.
No selecciones **Provision selected catalog** hasta que el publicador lo actualice.

Portolan es una especificación y un conjunto de herramientas para publicar datos
geoespaciales a cualquier escala. El plugin interpreta el catálogo y delega la
lectura de GeoParquet y PMTiles a los datastores instalados en GeoServer Cloud.

## Comandos

```text
make download  descarga y verifica los archivos publicados
make up        inicia el Compose
make setup     inicia el Compose y publica la capa OSM
make verify    prueba las versiones, el plugin y WFS
make query     ejecuta una consulta WFS acotada
make map       ejecuta una consulta WMS acotada
make viewer    muestra la URL del cliente OpenLayers
make ps        muestra el estado de los servicios
make logs      sigue los logs principales
make down      detiene los servicios y conserva los datos
make reset     elimina los contenedores y los volúmenes del POC
make test      valida los scripts y los valores fijados
```

`make setup` es idempotente. Puedes ejecutarlo otra vez sin duplicar recursos.

## Archivos descargados

El directorio ignorado `runtime/` contiene:

```text
runtime/compose.yml
runtime/geoserver-portolan-0.4.1-cloud.zip
```

El script verifica el SHA-256 del ZIP del plugin.
También rechaza un Compose que no use GeoServer Cloud 3.0.2.

Puedes usar un espejo con variables de entorno:

```bash
GSCLOUD_COMPOSE_URL=https://example.org/compose.yml \
PORTOLAN_CLOUD_URL=https://example.org/geoserver-portolan-0.4.1-cloud.zip \
make download
```

Conserva el mismo contenido o define `PORTOLAN_SHA256` con el checksum esperado.

## Solución de problemas

Revisa el estado y los logs:

```bash
make ps
make logs
```

Si cambiaste versiones o quedó un catálogo de una prueba anterior, reinicia todo:

```bash
make reset
make setup
```

`make reset` elimina los volúmenes de este POC. No afecta otros proyectos Compose.

Si la consulta remota tarda, confirma que tu red permite solicitudes por rangos
a `download.openplanetdata.com`. El script usa un tiempo de espera de 30 segundos.

## Fuentes

- [GeoServer Cloud 3.0.2](https://github.com/geoserver/geoserver-cloud/releases/tag/v3.0.2)
- [Guía REST del datastore Parquet](https://geoserver.org/geoserver-cloud/user-guide/geoparquet-rest-api/)
- [Release de geoserver-portolan 0.4.1](https://github.com/jemacchi/geoserver-portolan/releases/tag/v0.4.1)
- [OpenStreetMap en OpenPlanetData](https://openplanetdata.com/datasets/openstreetmap/)
- [Portolan](https://www.portolan-sdi.org/)
