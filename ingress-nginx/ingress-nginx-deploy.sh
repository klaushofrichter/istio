#!/bin/bash
# this installs ingress-nginx
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# remove existing deployment
./ingress-nginx-undeploy.sh

echo
echo "==== $0: Running helm for ingress-nginx, chart version ${INGRESSNGINXCHART}"
helm install -f ingress-nginx-values.yaml ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace --version ${INGRESSNGINXCHART}

#
# label the namespace for Goldilocks
[ "${GOLDILOCKS_ENABLE}" == "yes" ] && kubectl label namespace ingress-nginx goldilocks.fairwinds.com/enabled=true --overwrite

if [ "${RESOURCEPATCH}" == "yes" ]; then
  echo
  echo "==== $0: Patching ingress-nginx loadbalancer resources spec into the Daemonset"
  kubectl rollout status daemonset.apps svclb-ingress-nginx-controller -n ingress-nginx --request-timeout 5m
  kubectl patch daemonset svclb-ingress-nginx-controller -n ingress-nginx -p '{"spec":{"template":{"spec":{"containers":[{"name":"lb-port-80","resources":{"limits": { "cpu": "100m", "memory": "200M" }, "requests":{"cpu":"10m","memory":"50M"}}}]}}}}' 
  #kubectl patch daemonset svclb-ingress-nginx-controller -n ingress-nginx -p '{"spec":{"template":{"spec":{"containers":[{"name":"lb-port-443","resources":{"limits": { "cpu": "100m", "memory": "200M" }, "requests":{"cpu":"10m","memory":"50M"}}}]}}}}'
fi

echo 
echo "==== $0: Wait for rollout completing"
kubectl rollout status deployment.apps ingress-nginx-controller -n ingress-nginx --request-timeout 5m
kubectl rollout status daemonset.apps svclb-ingress-nginx-controller -n ingress-nginx --request-timeout 5m
x="0"
echo -n "Waiting for ingress-nginx-controller to get an IP address.."
while [ true ]; do
  LBIP=$(kubectl get svc ingress-nginx-controller --template="{{range .status.loadBalancer.ingress}}{{.ip}} {{end}}" -n ingress-nginx)
  [ ! -z "${LBIP}" ] && echo && echo "IP number is ${LBIP}" && break
  echo -n "."
  x=$(( ${x} + 2 ))
  [ ${x} -gt "100" ] && echo "ingress-nginx-controller not ready after ${x} seconds. Exit." && exit 1
  sleep 2
done
