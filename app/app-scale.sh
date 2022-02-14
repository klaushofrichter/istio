#!/bin/bash
#
# this script scales a deployment, either ${APP)-green (default) or $(APP}-blue. 
# first mandatory argument is the future scale, second argument is optionally the namespace
# This only works when keda is disabled.
#

set -e
[ -z ${PROJECTHOME} ] && echo "PROJECTHOME not set. Use \"export PROJECTHOME=\$(pwd)\" in the projects home directory" && exit 1
source ${PROJECTHOME}/config.sh

[ -z "$1" ] && echo "need one argument to scale. Exit." && exit 1
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

echo
echo "==== $0: Confirming Namespace to scale" 
export NAMESPACE="${APP}-green"
if [ ! -z "${2}" ]; then
  if [ "${2}" != "${APP}-green" ] && [ "${2}" != "${APP}-blue" ]; then
    echo "Second argument was \"${2}\", that is neither \"${APP}-green\" nor \"${APP}-blue\". Exit 1"
    exit 1
  fi
  NAMESPACE=${2}
fi
echo "Target namespace for $0 is \"${NAMESPACE}\", scaling ${APP} to \"${1}\""

kubectl scale --replicas=$1 deployment ${APP}-deploy -n ${NAMESPACE}
kubectl rollout status deployment.apps ${APP}-deploy -n ${NAMESPACE} --request-timeout 5m

[ "${KEDA_ENABLE}" == "yes" ] && echo "Note: Keda is enabled, which is interfering with the scaling"
