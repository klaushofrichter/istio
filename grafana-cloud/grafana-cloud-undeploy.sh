#!/bin/bash
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
export NAMESPACE=grafana-cloud

#
# require KUBECONFIG
[ -z "${KUBECONFIG}" ] && echo "$0: KUBECONFIG not set. Exit." && exit 1

#
# Delete the namespace if present
echo
if [[ ! -z $(kubectl get namespace | grep "^${NAMESPACE}" ) ]]; then

  echo "==== $0: Delete Grafana-Cloud deployment"
  MANIFEST_URL=https://raw.githubusercontent.com/grafana/agent/main/production/kubernetes/agent-bare.yaml
  curl -fsSL https://raw.githubusercontent.com/grafana/agent/release/production/kubernetes/install-bare.sh > /tmp/grafana-cloud-uninstall.sh
  /bin/sh -c "$(cat /tmp/grafana-cloud-uninstall.sh)" > /tmp/grafana-cloud-uninstall.yaml
  kubectl delete -f /tmp/grafana-cloud-uninstall.yaml || true
  #/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/grafana/agent/release/production/kubernetes/install-bare.sh)" | kubectl delete -f - -n ${NAMESPACE} || true

  echo
  echo "==== $0: Delete Grafana-Cloud configuration"
  cat grafana-cloud.yaml.template | envsubst | kubectl delete -f - -n ${NAMESPACE} || true

  echo
  echo "==== $0: Delete namespace \"${NAMESPACE}\" (this may take a while)"
  kubectl delete namespace ${NAMESPACE}

else

  echo "==== $0: Namespace \"${NAMESPACE}\" does not exist"
  echo "no need to remove."

fi 
