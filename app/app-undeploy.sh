#!/bin/bash
# this uninstalls the app from a namespace. 
# traffic will be redirected if there is a second namespace and Istio is enabled.
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

echo
echo "==== $0: Confirming Namespace to undeploy"
export NAMESPACE="${APP}-green"
export OTHERNAMESPACE="${APP}-blue"
export GREENWEIGHT=0
export BLUEWEIGHT=100
if [ ! -z "${1}" ]; then
  if [ "${1}" != "${APP}-green" ] && [ "${1}" != "${APP}-blue" ]; then
    echo "Argument was ${1}, that is neither \"${APP}-green\" nor \"${APP}-blue\". Exit 1"
    exit 1
  fi
  if [ "${1}" == "${APP}-blue" ]; then
    OTHERNAMESPACE="${APP}-green"
    NAMESPACE="${APP}-blue"
    GREENWEIGHT=100
    BLUEWEIGHT=0
  fi
fi
echo "Target namespace for deletion is ${NAMESPACE}"

# if the other namespace does not exist, delete the shared virtualservice and secondary ingress
if [ -z "$(kubectl get ns ${OTHERNAMESPACE} --ignore-not-found | grep ^${OTHERNAMESPACE})" ]; then

  echo
  echo "==== $0: Neither ${NAMESPACE} nor ${OTHERNAMESPACE} exists. Removing shared objects..."
  echo "Delete shared VirtualService to the app (this may fail if Isio CRDs are not present)"
  kubectl delete virtualservice ${APP} -n istio-gateway --ignore-not-found || true 
  echo "Delete shared secondary Ingress from ingress-nginx via istio to the app"
  kubectl delete ingress ${APP}-ingress -n istio-gateway --ignore-not-found
  echo "done."

else 

  if [ "${ISTIO_ENABLE}" == "yes" ]; then

    # Route all the traffic to the other namespace, and leave the secondary ingress in place.
    # Doing this will ensure "zero downtime" as we use the other namespace.

    echo
    echo "==== $0: ${NAMESPACE} to be removed, but ${OTHERNAMESPACE} exists"
    echo "Routing traffic to ${OTHERNAMESPACE} only"
    ./app-canary.sh ${GREENWEIGHT} ${BLUEWEIGHT}
    sleep 3 # give the VirtualService a little time to utilize the new route before removing the target namespace

  fi

fi

#
# Delete app installation and namespace if target namespace is present
if [ ! -z "$(kubectl get namespace | grep "^${NAMESPACE}" )" ]; then

  echo
  echo "==== $0: Delete HPA (it may fail)"
  kubectl delete hpa hpa-${APP}-cpu-utilization -n ${NAMESPACE} --ignore-not-found
  echo "done."

  echo
  echo "==== $0: Delete primary ingress (it may fail, it only exists with Istio disabled)"
  kubectl delete ingress ${NAMESPACE}-ingress -n ${NAMESPACE} --ignore-not-found
  echo "done."

  echo
  echo "==== $0: Delete Prometheus rules for ${APP} in ${NAMESPACE}"
  cat app-prometheus-rule.yaml.template | envsubst | kubectl delete -f - --ignore-not-found
  echo "done."

  echo
  echo "==== $0: Delete ScaledObject (this may fail, it only exist with Keda enabled)"
  cat app-scaledobject.yaml.template | envsubst | kubectl delete -f - --ignore-not-found || true
  echo "done."

  echo
  echo "==== $0: Delete application"
  cat app.yaml.template | envsubst | kubectl delete -f - --ignore-not-found
  echo "done."

  echo 
  echo "==== $0: Delete namespace \"${NAMESPACE}\""
  kubectl delete namespace ${NAMESPACE}

else

  echo
  echo "==== $0: Namespace \"${NAMESPACE}\" does not exist"
  echo "nothing to do."

fi

