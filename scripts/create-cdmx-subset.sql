INSTALL httpfs;
INSTALL spatial;
LOAD httpfs;
LOAD spatial;

SET memory_limit = '8GB';
SET temp_directory = 'duckdb-tmp';

COPY (
    WITH
    aoi AS (
        SELECT ST_MakeEnvelope(
            -99.364,
             19.048,
            -98.940,
             19.592
        ) AS geometry
    ),
    selected AS MATERIALIZED (
        SELECT
            source.osm_type,
            source.osm_id,
            source.tags,
            source.geometry
        FROM read_parquet(
            'https://download.openplanetdata.com/osm/planet/geoparquet/v1/planet-latest.osm.parquet'
        ) AS source
        CROSS JOIN aoi
        WHERE source.bbox.xmax >= -99.364
          AND source.bbox.xmin <= -98.940
          AND source.bbox.ymax >=  19.048
          AND source.bbox.ymin <=  19.592
          AND ST_Intersects(source.geometry, aoi.geometry)
    ),
    bounds AS (
        SELECT
            ST_Extent(ST_Extent_Agg(geometry))::BOX_2D AS geometry
        FROM selected
    )
    SELECT selected.*
    FROM selected
    CROSS JOIN bounds
    ORDER BY ST_Hilbert(selected.geometry, bounds.geometry)
)
TO 'osm-cdmx-hilbert-rg16k.parquet' (
    FORMAT PARQUET,
    GEOPARQUET_VERSION 'V2',
    COMPRESSION ZSTD,
    ROW_GROUP_SIZE 16384
);
