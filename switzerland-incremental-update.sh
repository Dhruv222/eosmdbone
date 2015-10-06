#!/bin/sh
#
# Updates Switzerland OSM data with osmosis and osm2pgsql

update_postgisterminal_timestamps() {
    local POSTGIS_TERMINAL_WWW_DIR=/var/www/postgisterminal
    local POSTGIS_TERMINAL_HOST=sifsv-80017.ifs.hsr.ch
    echo "***** updating timestamp on postgisterminal *****"
    ssh ifs@$POSTGIS_TERMINAL_HOST "cp $POSTGIS_TERMINAL_WWW_DIR/config_orig.php $POSTGIS_TERMINAL_WWW_DIR/config.php;\
      cp $POSTGIS_TERMINAL_WWW_DIR/index_orig.html $POSTGIS_TERMINAL_WWW_DIR/index.html;\
      cp $POSTGIS_TERMINAL_WWW_DIR/about-db-query_orig.php $POSTGIS_TERMINAL_WWW_DIR/about-db-query.php"
    ADAPT_TSTMP_CMD="sed -i s/[0-3][0-9]\.[01][0-9]\.20[0-9][0-9]\ [0-2][0-9]:[0-5][0-9]/$(date +'%d.%m.%Y\ %H:%M')/"
    ssh ifs@$POSTGIS_TERMINAL_HOST "$ADAPT_TSTMP_CMD $POSTGIS_TERMINAL_WWW_DIR/config.php\
      $POSTGIS_TERMINAL_WWW_DIR/index.html $POSTGIS_TERMINAL_WWW_DIR/about-db-query.php"
}

refresh_switzerland_data() {
    echo "***** refresh switzerland data *****"
    osmosis --read-replication-interval workingDirectory=/home/ifs/.osmosis --simplify-change\
      --write-xml-change /home/ifs/changes-switzerland.osc.gz
    osm2pgsql --slim --cache 16000 --extra-attributes --database gis_db --prefix osm\
      --style /usr/local/share/osm2pgsql/terminal.style --number-processes 8 --username postgres\
      --port 8080 --hstore-all --append /home/ifs/changes-switzerland.osc.gz
}

refresh_switzerland_data && update_postgisterminal_timestamps
