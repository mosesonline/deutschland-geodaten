FROM imresamu/postgis-arm64:16-master
RUN apt-get update && apt-get install -y --no-install-recommends \
  osm2pgsql wget
COPY ./init.sh /docker-entrypoint-initdb.d
