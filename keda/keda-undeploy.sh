#!/bin/bash
# this uninstalls keda
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# Delete keda installation and namespace if namespace is present
if [[ ! -z $(kubectl get namespace | grep "^keda" ) ]]; then

  echo
  echo "==== $0: Remove scaled object spec from two namespaces (this may fail)"
  export NAMESPACE="${APP}-green"
  cat ${PROJECTHOME}/app/app-scaledobject.yaml.template | envsubst | kubectl delete -f - --ignore-not-found
  export NAMESPACE="${APP}-blue"
  cat ${PROJECTHOME}/app/app-scaledobject.yaml.template | envsubst | kubectl delete -f - --ignore-not-found
  echo "done."

  echo
  echo "==== $0: Removing CRDs belonging to keda (this may fail)"
  kubectl delete crd scaledjobs.keda.sh || true
  kubectl delete crd scaledobjects.keda.sh || true
  kubectl delete crd triggerauthentications.keda.sh || true
  kubectl delete crd clustertriggerauthentications.keda.sh || true

  echo
  echo "==== $0: Helm uninstall release (this may fail)"
  helm uninstall keda -n keda || true

  echo
  echo "==== $0: Delete namespace \"keda\" (this may take a while)"
  kubectl delete namespace keda

else

  echo
  echo "==== $0: Namespace \"keda\" does not exist"
  echo "nothing to do."

fi

