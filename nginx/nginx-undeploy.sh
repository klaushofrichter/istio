#!/bin/bash
# this uninstalls nginx
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# Delete dashboard installation and namespace if namespace is present
if [[ ! -z $(kubectl get namespace | grep "^nginx" ) ]]; then

  echo
  echo "==== $0: Helm uninstall release (this may fail)"
  helm uninstall nginx -n nginx || true

  echo 
  echo "==== $0: Remove config map with static HTML site"
  kubectl delete configmap nginx-html -n nginx  --ignore-not-found

  echo
  echo "==== $0: Delete namespace \"nginx\" (this may take a while)"
  kubectl delete namespace nginx

else

  echo
  echo "==== $0: Namespace \"nginx\" does not exist"
  echo "nothing to do."

fi

