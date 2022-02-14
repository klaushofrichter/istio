#!/bin/bash
# this uninstalls goldilocks
set -e
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# Delete goldilocks installation and namespace if namespace is present
if [[ ! -z $(kubectl get namespace | grep "^goldilocks" ) ]]; then

  echo
  echo "==== $0: Helm uninstall release (this may fail or take a long time)"
  helm uninstall goldilocks -n goldilocks || true

  echo
  echo "==== $0: Delete namespace \"goldilocks\" (this may take a while)"
  kubectl delete namespace goldilocks

else

  echo
  echo "==== $0: Namespace \"goldilocks\" does not exist"
  echo "nothing to do."

fi

