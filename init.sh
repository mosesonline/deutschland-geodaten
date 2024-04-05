#!/bin/bash
if [ ! -f "/tmp/germany-latest.osm.pbf" ]; then
    wget https://download.geofabrik.de/europe/germany-latest.osm.pbf -O /tmp/germany-latest.osm.pbf
fi
echo "localhost:5432:${POSTGRES_DB}:${POSTGRES_USER}:${POSTGRES_PASSWORD}" > ~/.pgpass
export PGPASSFILE=~/.pgpass
cat ${PGPASSFILE}
osm2pgsql -c /tmp/germany-latest.osm.pbf -d "${POSTGRES_DB}" --slim --cache 4000 -I -U ${POSTGRES_USER}
#rm -f /tmp/germany-latest.osm.pbf

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL

DROP TABLE IF EXISTS public.osm2pgsql_properties;
DROP TABLE IF EXISTS public.planet_osm_line;
DROP TABLE IF EXISTS public.planet_osm_nodes;
DROP TABLE IF EXISTS public.planet_osm_point;
DROP TABLE IF EXISTS public.planet_osm_polygon;
DROP TABLE IF EXISTS public.planet_osm_roads;
DROP TABLE IF EXISTS public.planet_osm_rels;
DROP TABLE IF EXISTS public.planet_osm_ways;
DELETE FROM public.planet_osm_polygon WHERE "addr:country" <> 'DE' OR "addr:city" IS NULL OR "addr:street"  IS NULL OR "addr:postcode" IS NULL OR "addr:housenumber" = '-1';

UPDATE public.planet_osm_polygon SET "addr:postcode" = REPLACE("addr:postcode", '-','') WHERE "addr:postcode" ~ '^\d{2}-';
UPDATE public.planet_osm_polygon SET "addr:housenumber" = REGEXP_REPLACE("addr:housenumber", '"', '') WHERE "addr:housenumber" ~ '^".*"$';

CREATE EXTENSION pg_trgm;

ALTER TABLE public.planet_osm_polygon ADD COLUMN address TEXT;

UPDATE public.planet_osm_polygon SET address = 
    coalesce("addr:street",'') || ' ' || coalesce("addr:housenumber",'') || ' ' || coalesce("addr:postcode",'') || ' ' || coalesce( "addr:city",'')
    WHERE "addr:country" IS NOT NULL;

ALTER TABLE public.planet_osm_polygon ADD COLUMN text_search tsvector;
UPDATE public.planet_osm_polygon SET text_search =
       to_tsvector(coalesce("addr:street",'') || ' ' || coalesce("addr:housenumber",'') || ' ' || coalesce("addr:postcode",'') || ' ' || coalesce( "addr:city",''))
       WHERE "addr:country" IS NOT NULL;

CREATE INDEX IF NOT EXISTS address_exact_search ON public.planet_osm_polygon USING btree("addr:housenumber", "addr:street", "addr:city", "addr:postcode");
CREATE INDEX IF NOT EXISTS address_postcode_search ON public.planet_osm_polygon USING btree("addr:postcode");
CREATE INDEX IF NOT EXISTS address_street_search ON public.planet_osm_polygon USING btree("addr:street");
CREATE INDEX IF NOT EXISTS address_city_search ON public.planet_osm_polygon USING btree( "addr:city");
CREATE INDEX IF NOT EXISTS planet_osm_polygon_address_trgm ON public.planet_osm_polygon USING gist(address gist_trgm_ops);
CREATE INDEX name ON public.planet_osm_polygon USING gist(text_search);
EOSQL
