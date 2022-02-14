#!/bin/bash
# this uninstalls the Kubernetes Dashboard
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

echo
echo "==== $0: Remove RBAC and ServiceMonitor"
kubectl delete -f kubernetes-dashboard.yaml --ignore-not-found
echo "done."

#
# Delete dashboard installation and namespace if namespace is present
if [[ ! -z $(kubectl get namespace | grep "^kubernetes-dashboard" ) ]]; then

  echo
  echo "==== $0: Helm uninstall release (this may fail)"
  helm uninstall kubernetes-dashboard -n kubernetes-dashboard || true
  #kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v${KUBERNETES_DASHBOARD}/aio/deploy/recommended.yaml || true

  echo
  echo "==== $0: Delete namespace \"kubernetes-dashboard\" (this may take a while)"
  kubectl delete namespace kubernetes-dashboard 

else

  echo
  echo "==== $0: Namespace \"kubernetes-dashboard\" does not exist"
  echo "nothing to do."

fi

