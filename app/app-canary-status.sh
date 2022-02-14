#!/bin/bash
# 
# This shows the current canary deployment 

set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

echo
echo "==== $0: VirtualService ${APP} in namespace istio-gateway"
VS=$(kubectl get virtualservice ${APP} -n istio-gateway --ignore-not-found -o json)
if [ -z "${VS}" ]; then

  echo "No VirtualService ${APP} in namespace istio-gateway installed"

else

  GREENDESTINATION=$(echo ${VS} | jq '.spec.http[0].route[] | select(.destination.host=="myapp-service.myapp-green.svc.cluster.local")')
  BLUEDESTINATION=$(echo ${VS} | jq '.spec.http[0].route[] | select(.destination.host=="myapp-service.myapp-blue.svc.cluster.local")')
  if [ ! -z "${GREENDESTINATION}" ]; then
    echo -n "Green Route exists"
    GREENWEIGHT=$(echo "${GREENDESTINATION}" | jq -r .weight)
    [ ! "${GREENWEIGHT}" == "null" ] && echo -n " with weight ${GREENWEIGHT}."
    [ "${GREENWEIGHT}" == "null" ] && echo -n " without weight specification (i.e. 100% is routed to Green)."
    echo
  else
    echo "Green Route does not exist"
  fi
  if [ ! -z "${BLUEDESTINATION}" ]; then
    echo -n "Blue Route exists"
    BLUEWEIGHT=$(echo "${BLUEDESTINATION}" | jq -r .weight)
    [ ! "${BLUEWEIGHT}" == "null" ] && echo -n " with weight ${BLUEWEIGHT}."
    [ "${BLUEWEIGHT}" == "null" ] && echo -n " without weight specification (i.e. 100% is routed to Blue)."
    echo
  else
    echo "Blue Route does not exist"
  fi

  echo
  echo "==== $0: Route Detail:"
  echo ${VS} | jq '.spec.http[0].route[]'

fi
