#!/bin/bash
# this installs istio
set -e
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# If a VirtualService exists, save and reinstall later, as the VirtualService is in this namespace but not generated here.
#   The issue here is that we delete the namespace, but the VirtualService is created by app-deploy.sh. So, if you have a 
#   running cluster and restart with ./istio-deploy.sh, the VirtualService would not be created.
# 
[ ! -z "$(kubectl get crd | grep ^virtualservices.networking.istio.io)" ] && VIRTUALSERVICE=$(kubectl get virtualservice ${APP} -n istio-gateway -o json --ignore-not-found)
if [ ! -z "${VIRTUALSERVICE}" ]; then
  echo
  echo "==== $0: There is already a VirtualService installed"
  GREENDESTINATION=$(echo ${VIRTUALSERVICE} | jq '.spec.http[0].route[] | select(.destination.host=="myapp-service.myapp-green.svc.cluster.local")')
  BLUEDESTINATION=$(echo ${VIRTUALSERVICE} | jq '.spec.http[0].route[] | select(.destination.host=="myapp-service.myapp-blue.svc.cluster.local")')
  GREENWEIGHT="0"
  BLUEWEIGHT="0"
  if [ ! -z "${GREENDESTINATION}" ]; then
    GREENWEIGHT=$(echo ${GREENDESTINATION} | jq -r ".weight")
    [ "${GREENWEIGHT}" == "null" ] && GREENWEIGHT="100"
  fi
  if [ ! -z "${BLUEDESTINATION}" ]; then
    BLUEWEIGHT=$(echo ${BLUEDESTINATION} | jq -r ".weight")
    [ "${BLUEWEIGHT}" == "null" ] && BLUEWEIGHT="100"
  fi
  echo "The VirtualService will be restored after istio rollout."
  echo "Extracted weights: Green: ${GREENWEIGHT}  Blue: ${BLUEWEIGHT}"
fi

#
# check for the ingress (secondary route)
#   Same situation as for the VirtualService above
INGRESS=$(kubectl get ingress ${APP}-ingress -n istio-gateway --ignore-not-found | grep ${APP}-ingress) || true
if [ ! -z "${INGRESS}" ]; then
  echo
  echo "==== $0: There is already a shared Ingress as secondary route"
  echo "The ingress ${APP}-ingress in namespace istio-gateway will be restored after Istio rollout"
fi

#
# remove existing installation
./istio-undeploy.sh

echo
echo "==== $0: Deploy istio-base, chart version ${ISTIOBASECHART}"
helm install istio-base istio/base -f istio-base-values.yaml --version ${ISTIOBASECHART} -n istio-system --create-namespace

echo
echo "==== $0: Deploy istiod, chart version ${ISTIODCHART}"
helm install istiod istio/istiod -f istio-istio-values.yaml --version ${ISTIODCHART} -n istio-system

echo 
echo  "==== $0: Deploy istio gateway, chart version ${ISTIOGATEWAYCHART}"
helm install istio-gateway istio/gateway -f istio-gateway-values.yaml --version ${ISTIOGATEWAYCHART} -n istio-gateway --create-namespace

#
# label the namespace for Goldilocks
if [ "${GOLDILOCKS_ENABLE}" == "yes" ]; then
  echo
  echo "==== $0: Label istio-system and istio-gateway namespaces for Goldilocks"
  kubectl label namespace istio-system goldilocks.fairwinds.com/enabled=true --overwrite
  kubectl label namespace istio-gateway goldilocks.fairwinds.com/enabled=true --overwrite
fi

echo
echo "==== $0: Wait for istiod to finish deployment"
kubectl rollout status deployment.apps istiod -n istio-system --request-timeout 5m

#
# patch the resources for vpa and dashboard
if [ "${RESOURCEPATCH}" == "yes" ]; then

  echo
  echo "==== $0: Patching resources for istio gateway LBs in the Deployment"
  kubectl rollout status DaemonSets svclb-istio-gateway -n istio-gateway --request-timeout 5m
  kubectl patch DaemonSets svclb-istio-gateway -n istio-gateway -p '{"spec":{"template":{"spec":{"containers":[ {"name":"lb-port-81", "resources":{"limits":{"cpu":"100m","memory":"1Mi"},"requests":{"cpu":"50m","memory":"500Ki"}}}, {"name":"lb-port-443", "resources":{"limits":{"cpu":"100m","memory":"1Mi"},"requests":{"cpu":"50m","memory":"500Ki"}}}, {"name":"lb-port-15021", "resources":{"limits":{"cpu":"100m","memory":"1Mi"},"requests":{"cpu":"50m","memory":"500Ki"}}} ]}}}}'

fi

echo
echo "==== $0: Wait for istio-gateway to finish deployment"
kubectl rollout status deployment.apps istio-gateway -n istio-gateway --request-timeout 5m

#
# We need to restart the green and blue deployments (if they exist already) to connect the istio proxies to the
# new istio instance. There is a service interruption because the current proxies are not connected properly.
if [ ! -z "$(kubectl get deployment ${APP}-deploy -n ${APP}-green --ignore-not-found | grep ^${APP}-deploy)" ]; then
  echo
  echo "==== $0: Restarting ${APP} Deployment in the Green Namespace"
  kubectl rollout restart deployment ${APP}-deploy -n ${APP}-green
  kubectl rollout status deployment ${APP}-deploy -n ${APP}-green --request-timeout 5m
fi
if [ ! -z "$(kubectl get deployment ${APP}-deploy -n ${APP}-blue --ignore-not-found | grep ^${APP}-deploy)" ]; then
  echo
  echo "==== $0: Restarting ${APP} Deployment in the Blue Namespace"
  kubectl rollout restart deployment ${APP}-deploy -n ${APP}-blue
  kubectl rollout status deployment ${APP}-deploy -n ${APP}-blue --request-timeout 5m
fi

echo
echo "==== $0: Configure Gateway Instance to enable routing"
kubectl apply -f istio-gateway.yaml

#
# Restore the VS if there was one in the beginning
if [ ! -z "${VIRTUALSERVICE}" ]; then
  echo
  echo "==== $0: Restore previously existing VirtualService using Green ${GREENWEIGHT} and Blue ${BLUEWEIGHT}"
  echo "Using ../app-canary.sh to create the VirtualService"
  (cd ../app; ./app-canary.sh ${GREENWEIGHT} ${BLUEWEIGHT})
fi

#
# Restore the secondary Ingress if there was one in the beginning
if [ ! -z "${INGRESS}" ]; then
  echo 
  echo "==== $0: Restore the previously existing secondary Ingress route"
  cat ../app/app-ingress-istio.yaml.template | envsubst | kubectl apply -f -
fi

