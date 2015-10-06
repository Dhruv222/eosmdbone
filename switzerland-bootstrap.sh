#!/bin/sh
#
# Bootstrap script which
#
# - Creates a PostGIS DB
# - Initializes osmosis
# - Fills initial OSM data for Switzerland
# - Creates necessary indices
# - Performs a vacuum (really :-))
# - and creates auxiliary OSM views needed by consumer applications

DB_NAME=gis_db
DB_USER=readonly
WORKDIR_OSM=/home/ifs/.osmosis

# SQL
CREATE_INDEX_POINT="CREATE INDEX osm_point_tags_idx ON osm_point USING GIST(tags) WITH (fillfactor=100);
    CREATE INDEX osm_point_name_idx ON osm_point(name) WITH (fillfactor=100);
    CLUSTER osm_point USING osm_point_name_idx;"
CREATE_INDEX_LINE="CREATE INDEX osm_line_tags_idx ON osm_line USING GIST(tags) WITH (fillfactor=100);
    CREATE INDEX osm_line_name_idx ON osm_line(name) WITH (fillfactor=100);
    CLUSTER osm_line USING osm_line_name_idx;"
CREATE_INDEX_POLYGON="CREATE INDEX osm_polygon_tags_idx ON osm_polygon USING GIST(tags) WITH (fillfactor=100);
    CREATE INDEX osm_polygon_name_idx ON osm_polygon(name) WITH (fillfactor=100);
    CLUSTER osm_polygon USING osm_polygon_name_idx;"
CREATE_INDEX_OSM_POI="CREATE INDEX ON osm_poi USING GIST(way); CREATE INDEX ON osm_poi(name) WITH (fillfactor=100);
    CREATE INDEX ON osm_poi USING GIST(tags) WITH (fillfactor=100);"
CREATE_INDEX_OSM_ALL="CREATE INDEX ON osm_all USING GIST(way); CREATE INDEX ON osm_all(name) WITH (fillfactor=100);
    CREATE INDEX ON osm_all USING GIST(tags) WITH (fillfactor=100);"
CREATE_OSM_POI_VIEW="CREATE OR REPLACE VIEW osm_poi (osm_id, name, tags, gtype, osm_version, way) AS\
    SELECT osm_point.osm_id, osm_point.name, osm_point.tags, 'pt', osm_point.osm_version, osm_point.way FROM osm_point\
    UNION SELECT osm_polygon.osm_id, osm_polygon.name, osm_polygon.tags, 'po', osm_polygon.osm_version, ST_Centroid(osm_polygon.way) FROM osm_polygon;"
CREATE_OSM_ALL_VIEW="CREATE OR REPLACE VIEW osm_all (osm_id, name, tags, gtype, osm_version, way) AS\
    SELECT osm_id, name, tags, 'pt', osm_version, way FROM osm_point UNION SELECT osm_id, name, tags, 'ln', osm_version, way FROM osm_line\
    UNION SELECT osm_id, name, tags, 'po', osm_version, way FROM osm_polygon;"


execute_sql() {
    psql --dbname $DB_NAME -c "$1" -U postgres
}

setup_db() {
    echo "*** setup DB with postgis extensions ***"
    createuser -U postgres -S -D -R $DB_USER
    createdb   -U postgres -O $DB_USER $DB_NAME
    createlang -U postgres plpgsql $DB_NAME
    execute_sql "ALTER USER $DB_USER WITH PASSWORD 'Vainyils9';" 
    execute_sql "CREATE EXTENSION hstore;"
    psql -U postgres -d $DB_NAME -f /usr/share/postgresql/9.1/contrib/postgis-1.5/postgis.sql
    psql -U postgres -d $DB_NAME -f /usr/share/postgresql/9.1/contrib/postgis-1.5/spatial_ref_sys.sql
}

create_indices() {
    echo "***** creating indices *****" >&2
    execute_sql "$CREATE_INDEX_POINT"
    execute_sql "$CREATE_INDEX_LINE"
    execute_sql "$CREATE_INDEX_POLYGON"
    #execute_sql "$CREATE_INDEX_OSM_POI"
    #execute_sql "$CREATE_INDEX_OSM_ALL"
}

perform_vacuum() {
    echo "***** performing vacuum *****" >&2
    execute_sql "VACUUM FREEZE ANALYZE"
}

init_osmosis() {
    echo "*** init osmosis ***"
    mkdir -p $WORKDIR_OSM
    osmosis --read-replication-interval-init workingDirectory=$WORKDIR_OSM
    cp /home/ifs/switzerland-configuration.txt $WORKDIR_OSM/configuration.txt
}

fill_initial_osm_data() {
    echo "*** fill initial OSM data ***"
    wget -q http://download.geofabrik.de/europe/switzerland-latest.osm.pbf \
        -O switzerland-latest.osm.pbf
    osm2pgsql --slim --create --cache 16000 --extra-attributes --database $DB_NAME \
        --prefix osm --style /usr/local/share/osm2pgsql/terminal.style \
        --number-processes 8 --username postgres --port 8080 --hstore-all \
        --input-reader pbf switzerland-latest.osm.pbf 
}

create_aux_osm_views() {
    echo "***** creating auxiliary views *****" >&2
    execute_sql "$CREATE_OSM_POI_VIEW"
    execute_sql "$CREATE_OSM_ALL_VIEW"
}

grant_read_access_for_db_user() {
    #TODO we should restrict this to all tables with a "OSM" prefix
    execute_sql "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $DB_USER;"
}

setup_db && fill_initial_osm_data && create_aux_osm_views &&  create_indices && \
    perform_vacuum && grant_read_access_for_db_user && init_osmosis
