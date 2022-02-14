#!/bin/bash
# this uninstalls istio
set -e
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# Delete istio-gateway and namespace if namespace is present
if [[ ! -z $(kubectl get namespace | grep "^istio-gateway" ) ]]; then

  # This is disabled, because already installed istio gateways or virtual services would be deleted
  #echo 
  #echo "==== $0: Delete Istio CRDs"
  #kubectl get crd -oname | grep --color=never 'istio.io' | xargs kubectl delete
  
  echo
  echo "==== $0: Helm uninstall istio-gateway (this may fail)"
  helm uninstall istio-gateway -n istio-gateway || true

  echo
  echo "==== $0: Delete namespace \"istio-gateway\" (this may take a while)"
  kubectl delete namespace istio-gateway

else

  echo
  echo "==== $0: Namespace \"istio-gateway\" does not exist"
  echo "nothing to do."

fi

#
# Delete istio base and system namespace if namespace is present
if [[ ! -z $(kubectl get namespace | grep "^istio-system" ) ]]; then

  echo
  echo "==== $0: Helm uninstall istiod release (this may fail)"
  helm uninstall istiod -n istio-system || true

  echo
  echo "==== $0: Helm uninstall istio-base release (this may fail)"
  helm uninstall istio-base -n istio-system || true

  echo
  echo "==== $0: Delete namespace \"istio-system\" (this may take a while)"
  kubectl delete namespace istio-system

else

  echo
  echo "==== $0: Namespace \"istio-system\" does not exist"
  echo "nothing to do."

fi

