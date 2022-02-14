#!/bin/bash
# this installs the app into a namespace
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

echo
echo "==== $0: Confirming Namespace to deploy"
export NAMESPACE="${APP}-green"
export OTHERNAMESPACE="${APP}-blue"
if [ ! -z "${1}" ]; then
  if [ "${1}" != "${APP}-green" ] && [ "${1}" != "${APP}-blue" ]; then
    echo "Argument was ${1}, that is neither \"${APP}-green\" nor \"${APP}-blue\". Exit 1"
    exit 1
  fi
  if [ "${1}" == "${APP}-blue" ]; then
    OTHERNAMESPACE="${APP}-green"
    NAMESPACE="${APP}-blue"
  fi
fi
echo "Target namespace for ${APP} is ${NAMESPACE}"

#
# if the VirtualService exists, remember the load distribution to restore it after deployment
if [ ! -z "$(kubectl get  crd | grep virtualservices.networking.istio.io)" ]; then
  VS=$(kubectl get virtualservice ${APP} -n istio-gateway --ignore-not-found -o json)
  if [ ! -z "${VS}" ]; then

    echo 
    echo "==== $0: Extracting the Green/Blue route detail for restore later"
    GREENDESTINATION=$(echo ${VS} | jq '.spec.http[0].route[] | select(.destination.host=="myapp-service.myapp-green.svc.cluster.local")')
    if [ -z "${GREENDESTINATION}" ]; then
      GREENWEIGHT=0
    else
      GREENWEIGHT=$(echo "${GREENDESTINATION}" | jq -r .weight)
      [ "${GREENWEIGHT}" == "null" ] && GREENWEIGHT=100
    fi
    BLUEDESTINATION=$(echo ${VS} | jq '.spec.http[0].route[] | select(.destination.host=="myapp-service.myapp-blue.svc.cluster.local")')
    if [ -z "${BLUEDESTINATION}" ]; then
      BLUEWEIGHT=0
    else
      BLUEWEIGHT=$(echo "${BLUEDESTINATION}" | jq -r .weight)
      [ "${BLUEWEIGHT}" == "null" ] && BLUEWEIGHT=100
    fi
    echo "Green: ${GREENWEIGHT}%  Blue: ${BLUEWEIGHT}%"

  fi
fi

#
# remove existing deployment
./app-undeploy.sh ${NAMESPACE}

echo
echo "==== $0: Create the namespace"
kubectl create namespace ${NAMESPACE}

#
# Mark the namespace for istio if enabled
if [ "${ISTIO_ENABLE}" == "yes" ]; then

  echo
  echo "==== $0: Label namespace ${NAMESPACE} for istio"
  kubectl label namespace ${NAMESPACE} istio-injection=enabled

fi

echo
echo "==== $0: Deploy application (deployment, service, servicemonitor)"
export DEPLOYDATE=$(date "+%m/%d/%Y, %r")
echo "deployDate is ${DEPLOYDATE}"
cat app.yaml.template | envsubst | kubectl create -f - --save-config

echo
echo "==== $0: Wait for ${APP} deployment to finish"
kubectl rollout status deployment.apps ${APP}-deploy -n ${NAMESPACE} --request-timeout 5m

#
# Handle either Istio Gateway or ingress nginx routing
if [ "${ISTIO_ENABLE}" == "yes" ]; then

  # 
  # if there is no previous distribtion, we create a new one with 100% to the current namespace
  echo
  echo "==== $0: Using VirtualService. Determining weights"
  if [ -z ${GREENWEIGHT} ] && [ -z ${BLUEWEIGHT} ]; then
    GREENWEIGHT=100
    BLUEWEIGHT=0
    [ "${NAMESPACE}" == "${APP}-blue" ] && GREENWEIGHT=0 && BLUEWEIGHT=100
    echo "No previous distribution available. We use 100% for ${NAMESPACE}"
  else
    echo "Re-creating previous distribution of Green: ${GREENWEIGHT}%  Blue: ${BLUEWEIGHT}%"
  fi
  ./app-canary.sh ${GREENWEIGHT} ${BLUEWEIGHT}

  echo
  echo "==== $0: Create secondary route from ingress-nginx to istio (this is a redundant route, this may fail)"
  cat app-ingress-istio.yaml.template | envsubst | kubectl apply -f - || true

else

  echo
  echo "==== $0: Using ingress-nginx Ingress for primary routing"
  cat app-ingress.yaml.template | envsubst | kubectl create -f - --save-config

fi

# 
# if hpa is enabled, deploy it
if [ "${HPA_ENABLE}" == "yes" ]; then

  echo
  echo "==== $0: Installing HPA"
  cat app-hpa.yaml.template | envsubst | kubectl apply -f - -n ${NAMESPACE}
  
else

  #
  # if keda the keda scaleobject CRD exists, and we don't have HPA, deploy keda scaleobject for the app
  if [ "$(kubectl get crd | grep '^scaledobjects.keda.sh' | cut -d ' ' -f 1)" == "scaledobjects.keda.sh" ]; then
  
    echo 
    echo "==== $0: Deploying scaledobject for ${APP} because the CRD exists"
    cat app-scaledobject.yaml.template | envsubst | kubectl apply -f -
  fi

fi

#
# label the namespace for Goldilocks
if [ "${GOLDILOCKS_ENABLE}" == "yes" ]; then
  echo 
  echo "==== $0: Labeling the namespace for Goldilocks"
  kubectl label namespace ${NAMESPACE} goldilocks.fairwinds.com/enabled=true --overwrite
fi

echo 
echo "==== $0: Deploy Prometheus Rules for alert messages"
cat app-prometheus-rule.yaml.template | envsubst '$APP $CLUSTER $NAMESPACE' | kubectl apply -f -

#
# Wait for secondary ingress to be ready if we have Istio installed
if [ "${ISTIO_ENABLE}" == "yes" ]; then

  echo 
  echo "==== $0: Wait for secondary route ingress to be ready"
  echo -n "Checking for ingress-nginx Loadbalancer IP assignment.."
  while [ "$(kubectl get ing ${APP}-ingress -n istio-gateway -o json | jq -r .status.loadBalancer.ingress[0].ip)" = "null" ]
  do
    i=$[$i+1]
    [ "$i" -gt "60" ] && echo "this took too long... exit." && exit 1
    echo -n "."
    sleep 2
  done
  sleep 1
  echo
  echo "done."

else

  echo
  echo "==== $0: Wait for ingress to be ready"
  echo -n "Checking for ingress-nginx Loadbalancer IP assignment.."
  while [ "$(kubectl get ing ${NAMESPACE}-ingress -n ${NAMESPACE} -o json | jq -r .status.loadBalancer.ingress[0].ip)" = "null" ]
  do
    i=$[$i+1]
    [ "$i" -gt "60" ] && echo "this took too long... exit." && exit 1
    echo -n "."
    sleep 2
  done
  sleep 1
  echo
  echo "done."

fi

