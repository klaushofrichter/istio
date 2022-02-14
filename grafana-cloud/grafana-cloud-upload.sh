#!/bin/bash
# this uploads a dashboard JSON to the grafana cloud instance. An instance key with admin rights 
# needs to be generated at the Grafana-Cloud Grafana Instance (not the Grafana Cloud Portal).
# SW inspired by https://grafana.com/docs/grafana-cloud/fundamentals/find-and-use-dashboards/

set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh

#
# check for requires details (must exist and different from the predefined value)
[ -z ${GRAFANA_CLOUD_ORG} ] && echo "$0: missing GRAFANA_CLOUD_ORG definition in config.sh." && exit 1
[ -z ${GRAFANA_CLOUD_INSTANCE_KEY} ] && echo "$0: missing GRAFANA_CLOUD_INSTANCE_KEY definition in config.sh." && exit 1
[ "${GRAFANA_CLOUD_ORG}" == "YOURORGNAME" ] && echo "$0: missing GRAFANA_CLOUD_ORG customization in config.sh." && exit 1
[ "${GRAFANA_CLOUD_INSTANCE_KEY}" == "YOUR GRAFAN-CLOUD INSTANCE ADMIN API KEY" ] && echo "$0: missing GRAFANA_CLOUD_INSTANCE_KEY customization in config.sh." && exit 1

#
# check argument (must be one filename)
[ -z $1 ] && echo "Require one dashboard json filename as option" && exit 1
[ ! -f $1 ] && echo "$1 does not exist." && exit 1

echo
echo "==== $0: Uploading $(jq .title "$1") to Grafana at https://${GRAFANA_CLOUD_ORG}.grafana.net/"
dashboard_json='{"dashboard": '"$(jq '. | del(.id)' "$1")}"
curl -sSH "Content-Type: application/json" \
   -H "Authorization: Bearer ${GRAFANA_CLOUD_INSTANCE_KEY}" \
   -d "${dashboard_json}" "https://${GRAFANA_CLOUD_ORG}.grafana.net/api/dashboards/db"
   echo
echo "done."
