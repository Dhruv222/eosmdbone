#!/bin/sh
#
# Refreshes OSRM server with new CH data

# Config
CH_OSM_URL=download.geofabrik.de/openstreetmap/europe/switzerland.osm.pbf
MIN_OSM_FILE_SIZE=$((10*1024*1024)) # 10MB
TOURPL_HOST=sifsv-80016.hsr.ch
OSRM_BIN_DIRECTORY=/home/ifs/OSRM
TOURPL_LAYOUT_HTML_PATH=/var/www/tourpl/env/lib/python2.7/site-packages/Tourpl-1.0-py2.7.egg/tourpl/app/views/layout.html


init() {
    START_TIME=$(date +"%s")
}

get_data_for_switzerland() {
    echo "***** getting OSM data for switzerland *****"
    wget -q -O ${OSRM_BIN_DIRECTORY}/$(basename ${CH_OSM_URL}) ${CH_OSM_URL}
    size=$(stat -c %s "$OSRM_BIN_DIRECTORY/$(basename ${CH_OSM_URL})")
    [ $size -gt $MIN_OSM_FILE_SIZE ] || return 1 # sanity check (sometimes incomplete OSM data is published)
}

refresh_routing_information() {
    echo "***** stopping osm route server *****"
    kill $(ps -ef | grep [Rr]outed | grep -v grep | awk '{print $2}')
    sleep 5
    echo "***** refreshing routing information *****"
    cd ${OSRM_BIN_DIRECTORY} || ( echo "${OSRM_BIN_DIRECTORY} not available!" >&2; return 1 )
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${OSRM_BIN_DIRECTORY}
    ./osrm-extract $(basename ${CH_OSM_URL}) >/dev/null
    ./osrm-prepare switzerland.osrm switzerland.osrm.restrictions >/dev/null
    echo "***** starting osm route server *****"
    nohup ./osrm-routed >/dev/null &
}

update_consumer_timestamps() {
    echo "***** updating timestamp on web site *****"
    ADAPT_TSTMP_CMD="sed -i s/[0-3][0-9]\.[01][0-9]\.20[0-9][0-9]\ [0-2][0-9]:[0-5][0-9]/$(date +'%d.%m.%Y\ %H:%M')/"
    ssh ifs@$TOURPL_HOST "$ADAPT_TSTMP_CMD $TOURPL_LAYOUT_HTML_PATH"
}

finished() {
    END_TIME=$(date +"%s")
    echo "***** finished at $(date) - duration: $((($END_TIME-$START_TIME)/60)) minutes *****"
}

init && get_data_for_switzerland && refresh_routing_information && update_consumer_timestamps && finished
