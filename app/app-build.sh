#!/bin/bash
# this builds the app 
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

echo
echo "==== $0: Build app image ${APP}:${VERSION}"
npm install
docker build -t ${APP}:${VERSION} .

echo
echo "==== $0: Import new image ${APP}:${VERSION} to k3d ${CLUSTER} (this may take a while)"
k3d image import ${APP}:${VERSION} -c ${CLUSTER} --keep-tools

