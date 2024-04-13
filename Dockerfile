FROM imresamu/postgis-arm64:16-master
RUN apt-get update && apt-get install -y make cmake g++ libboost-dev \
  libexpat1-dev zlib1g-dev libpotrace-dev \
  libopencv-dev libbz2-dev libpq-dev libproj-dev lua5.3 liblua5.3-dev \
  pandoc nlohmann-json3-dev pyosmium git
RUN git clone https://github.com/osm2pgsql-dev/osm2pgsql && cd osm2pgsql && \
  mkdir build && cd build && cmake .. && sudo make install
RUN apt-get remove git make cmake
COPY ./init.sh /docker-entrypoint-initdb.d
