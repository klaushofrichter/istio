#!/bin/bash
# This updates the deployment with the current image. Build the image with ./app-build.sh
# A rolling update is then performed without service interruption.

set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

echo
echo "==== $0: Confirming Namespace to deploy"
export NAMESPACE="${APP}-green"
if [ ! -z "${1}" ]; then
  if [ "${1}" != "${APP}-green" ] && [ "${1}" != "${APP}-blue" ]; then
    echo "Argument was $1, that is neither \"${APP}-green\" nor \"${APP}-blue\". Exit 1"
    exit 1
  fi
  NAMESPACE=${1}
fi
echo "Target namespace for ${APP} is ${NAMESPACE}"

echo
echo "==== $0: Update application image and restart"
echo "Note: no new image is build. Use ./app-build.sh to create a new image"
export DEPLOYDATE=$(date "+%m/%d/%Y, %r")
echo "deployDate is ${DEPLOYDATE}"
kubectl set image deployment.apps/${APP}-deploy ${APP}-container=${APP}:${VERSION} -n ${NAMESPACE}
kubectl set env deployment/${APP}-deploy DEPLOYDATE="${DEPLOYDATE}" -n ${NAMESPACE}
kubectl rollout restart deployment.apps/${APP}-deploy -n ${NAMESPACE} --request-timeout 5m
kubectl annotate deployment.apps/${APP}-deploy kubernetes.io/change-cause="image update via $0" -n ${NAMESPACE}

echo
echo "==== $0: Wait for ${APP} update deployment to finish"
kubectl rollout status deployment.apps ${APP}-deploy -n ${NAMESPACE} --request-timeout 5m

