#!/bin/bash
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
export NAMESPACE="grafana-cloud"

#
# Require KUBECONFIG
[ -z "${KUBECONFIG}" ] && echo "$0: KUBECONFIG not set. Exit." && exit 1

#
# Delete deployment if it exists
./grafana-cloud-undeploy.sh -f ${CONFIG}

echo
echo "==== $0: Limiting the metrics export"
source ./grafana-cloud-metrics.sh
echo "done."

echo
echo "==== $0: Generating the Grafana Cloud Dashboard"
sed -i 's/myapp/${APP}/g' grafana-cloud-dashboard.json.template 
cat grafana-cloud-dashboard.json.template | envsubst "${ENVSUBSTVAR}" > grafana-cloud-dashboard.json
echo "Dashboard ./grafana-cloud-dashboard.json is ready for upload to Grafana Cloud."

#
# Create namespace for grafana cloud if it does not exist
if [ -z $(kubectl get namespace | grep "^${NAMESPACE}" | cut -d " " -f 1 ) ]; then
  echo
  echo "==== $0: Create namespace \"${NAMESPACE}\""
  kubectl create namespace ${NAMESPACE}
fi 

echo
echo "==== $0: Installing grafana-cloud agent into namespace \"${NAMESPACE}\""
MANIFEST_URL=https://raw.githubusercontent.com/grafana/agent/main/production/kubernetes/agent-bare.yaml
curl -fsSL https://raw.githubusercontent.com/grafana/agent/release/production/kubernetes/install-bare.sh > /tmp/grafana-cloud-install.sh
/bin/sh -c "$(cat /tmp/grafana-cloud-install.sh)" > /tmp/grafana-cloud-install.yaml
kubectl create -f /tmp/grafana-cloud-install.yaml -n ${NAMESPACE} || true
cat grafana-cloud.yaml.template | envsubst | kubectl apply -n ${NAMESPACE} -f - 
rm /tmp/grafana-cloud-install.yaml /tmp/grafana-cloud-install.sh

#
# label the namespace for Goldilocks
[ "${GOLDILOCKS_ENABLE}" == "yes" ] && kubectl label namespace grafana-cloud goldilocks.fairwinds.com/enabled=true --overwrite

#
# patch resource management if enabled
if [ "${RESOURCEPATCH}" == "yes" ]; then
  echo
  echo "==== $0: Patching grafana-cloud agent resource settings into the deployment"
  kubectl rollout status deployment.apps grafana-agent -n ${NAMESPACE} --request-timeout 5m
  kubectl patch deployment grafana-agent -n grafana-cloud -p '{"spec":{"template":{"spec":{"containers":[{"name":"agent","resources":{"limits":{"cpu":"800m","memory":"800M"},"requests":{"cpu":"200m","memory":"200M"}}}]}}}}' 
fi

echo 
echo "==== $0: Waiting for Grafana Cloud Agent to be deployed"
kubectl rollout restart deployment/grafana-agent -n ${NAMESPACE}
kubectl rollout status deployment.apps grafana-agent -n ${NAMESPACE} --request-timeout 5m

echo
echo "==== $0: check for fluentbit to include the loki output filter"
LOKI_OUTPUT=$(kubectl get configmap fluentbit-fluent-bit -n fluentbit -o yaml | grep "      Name loki") || true
if [ -z "${LOKI_OUTPUT}" ]; then
  echo -n "Fluentbit Loki output filter is not installed, need to rerun \"./fluentbit-deploy.sh\""
  [ "${GRAFANA_CLOUD_ENABLE}" != "yes" ] && echo -n " after setting GRAFANA_CLOUD_ENABLE to \"yes\" in \"config.sh\""
  echo
  exit 1
else
  echo "Fluentbit Loki Output is installed."
fi

