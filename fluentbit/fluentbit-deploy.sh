#!/bin/bash
# this installs fluentbit
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# remove existing installation
./fluentbit-undeploy.sh

echo
echo "==== $0: Deploy fluentbit with metrics exporter, chart version ${FLUENTBITCHART}"
if [ "${GRAFANA_CLOUD_ENABLE}" == "yes" ]; then
  echo "Deploying Fluentbit with Grafana Cloud support"
  LOKI_SUPPORT="fluentbit-values-loki.yaml.template"
else
  echo "Deploying Fluentbit without Grafana Cloud support (no Loki output filter)"
  unset LOKI_SUPPORT
fi
kubectl create namespace fluentbit
kubectl create configmap etcmachineidcm -n fluentbit --from-file=/etc/machine-id
cat fluentbit-values.yaml.template ${LOKI_SUPPORT} | envsubst | helm install -f - fluentbit fluent/fluent-bit --version ${FLUENTBITCHART} -n fluentbit

#
# label the namespace for Goldilocks
[ "${GOLDILOCKS_ENABLE}" == "yes" ] && kubectl label namespace fluentbit goldilocks.fairwinds.com/enabled=true --overwrite

echo
echo "==== $0: Wait for fluentbit to finish deployment"
kubectl rollout status daemonset.apps fluentbit-fluent-bit -n fluentbit --request-timeout 5m

