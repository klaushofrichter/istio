#!/bin/bash
# this installs influxdb
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# remove existing deployment
./influxdb-undeploy.sh

echo
echo "==== $0: Running helm for influxdb, chart version ${INFLUXDBCHART} (This takes a lot of time, need to find out why)."
helm install -f influxdb-values.yaml --set setDefaultUser.user.password=${INFLUXDB_LOCAL_ADMIN_PASSWORD} influxdb influxdata/influxdb \
 -n influxdb --create-namespace --version ${INFLUXDBCHART}

#
# label the namespace for Goldilocks
[ "${GOLDILOCKS_ENABLE}" == "yes" ] && kubectl label namespace influxdb goldilocks.fairwinds.com/enabled=true --overwrite

echo
echo "==== $0: Patch Nodeport to ${INFLUXPORT} and wait for rollout"
kubectl patch svc influxdb -n influxdb --type='json' -p "[{\"op\":\"replace\",\"path\":\"/spec/ports/0/nodePort\",\"value\":${INFLUXPORT}}]"
kubectl rollout status statefulsets.apps influxdb -n influxdb --request-timeout 5m

echo
echo "==== $0: Deploy Influxdb Stats Exporter"
cat influxdb-stats-exporter.yaml.template | envsubst | kubectl create -f -
kubectl rollout status deployments.apps influxdb-stats-exporter-deployment -n influxdb --request-timeout 5m

echo
echo "==== $0: Deploy Influx UI"
cat influxdb-ui.yaml.template | envsubst | kubectl create -f -
kubectl rollout status deployments.apps influxdb-ui-deployment -n influxdb --request-timeout 5m

echo 
echo "==== $0: Set default Retention Policy to one day"
INFLUXPOD=$(kubectl get pods -n influxdb | grep "^influxdb" | cut -d " " -f 1)
CMD="CREATE RETENTION POLICY one_day ON fluentbit DURATION 24h REPLICATION 1 DEFAULT"
kubectl exec ${INFLUXPOD} -n influxdb -- influx -username admin -password ${INFLUXDB_LOCAL_ADMIN_PASSWORD} -execute "$CMD"
CMD="show retention policies on fluentbit"
kubectl exec ${INFLUXPOD} -n influxdb -- influx -username admin -password ${INFLUXDB_LOCAL_ADMIN_PASSWORD} -execute "$CMD"

