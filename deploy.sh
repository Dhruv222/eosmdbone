#!/bin/sh

scp -p refresh-osrm-data.sh switzerland-bootstrap.sh switzerland-incremental-update.sh switzerland-configuration.txt ifs@sifs-80044.hsr.ch:
scp -p trobdb.lua ifs@sifs-80044.hsr.ch:/home/ifs/OSRM/Traffic/profile.lua
scp -p terminal.style ifs@sifs-80044.hsr.ch:/usr/local/share/osm2pgsql/terminal.style
scp -p osrm-alive-test.sh ifs@sifsv-80016.hsr.ch:
