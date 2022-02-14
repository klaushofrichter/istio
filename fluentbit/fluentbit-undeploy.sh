#!/bin/bash
# this uninstalls fluentbit
set -e
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# Delete fluentbit installation and namespace if namespace is present
if [[ ! -z $(kubectl get namespace | grep "^fluentbit" ) ]]; then

  echo
  echo "==== $0: Helm uninstall release (this may fail)"
  helm uninstall fluentbit -n fluentbit || true

  echo
  echo "==== $0: Delete configmap for etcmachineid (this may fail)"
  kubectl delete configmap etcmachineidcm -n fluentbit 

  echo
  echo "==== $0: Delete namespace \"fluentbit\" (this may take a while)"
  kubectl delete namespace fluentbit

else

  echo
  echo "==== $0: Namespace \"fluentbit\" does not exist"
  echo "nothing to do."

fi

