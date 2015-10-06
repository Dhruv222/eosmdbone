# cronjob settings (every hour except between 5 a.m. and 8 a.m.:
# 0 0-5,8-23 * * * /home/ifs/osrm_alive_test.sh

MAIL_RECIPIENTS='mrueegg@hsr.ch skeller@hsr.ch'
MAIL_FROM='info@tourpl.ch'
REQUEST_URL='http://sifs-80044.hsr.ch:5000/viaroute?loc=47.236787,8.830005&loc=47.236787,8.830008'
TIMEOUT=5 #in s

status=$(curl -o /dev/null --connect-timeout ${TIMEOUT} -silent --head --write-out '%{http_code}\n' $REQUEST_URL)
[ $status -ne 200 ] && mailx -r ${MAIL_FROM} -s "OSM Routing not available" ${MAIL_RECIPIENTS} << EOM
OSM Routing not available: Received status ${status} (000 means server is not reachable)
EOM
