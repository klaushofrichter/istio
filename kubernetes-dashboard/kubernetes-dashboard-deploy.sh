#!/bin/bash
# this installs kubernetes dashboard
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# remove existing installation
./kubernetes-dashboard-undeploy.sh

echo
echo "==== $0: Deploy kubernetes-dashboard, chart version ${KUBERNETESDASHBOARDCHART}"
cat kubernetes-dashboard-values.yaml.template | envsubst | helm install -f - kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --version ${KUBERNETESDASHBOARDCHART} -n kubernetes-dashboard --create-namespace

#
# label the namespace for Goldilocks
[ "${GOLDILOCKS_ENABLE}" == "yes" ] && kubectl label namespace kubernetes-dashboard goldilocks.fairwinds.com/enabled=true --overwrite

#
# patch resource management if enabled
if [ "${RESOURCEPATCH}" == "yes" ]; then
  echo
  echo "==== $0: Patching kubernetes-dashboard metrics scraper resource settings into the deployment"
  kubectl rollout status deployment.apps kubernetes-dashboard -n kubernetes-dashboard --request-timeout 5m
  kubectl patch deployment kubernetes-dashboard -n kubernetes-dashboard -p '{"spec":{"template":{"spec":{"containers":[{"name":"dashboard-metrics-scraper","resources":{"limits":{"cpu":"50m","memory":"40M"},"requests":{"cpu":"10m","memory":"20M"}}}]}}}}'
fi

echo 
echo "==== $0: Setup RBAC and service monitor"
kubectl apply -f kubernetes-dashboard.yaml

echo
echo "==== $0: Wait for kubernetes-dashboard to finish deployment"
kubectl rollout status deployment.apps kubernetes-dashboard -n kubernetes-dashboard --request-timeout 5m
i=0
echo -n "Wait for kubernetes-dashboard ingress to be available.."
while [ "$(kubectl get ing kubernetes-dashboard -n kubernetes-dashboard -o json | jq -r .status.loadBalancer.ingress[0].ip)" = "null" ]
do
  i=$[$i+1]
  [ "$i" -gt "60" ] && echo "this took too long... exit." && exit 1
  echo -n "."
  sleep 2
done
sleep 1
echo
echo "done"

echo 
echo "==== $0: Extract the token for login to the Kubernetes Dashboard"
echo "visit http://localhost:${HTTPPORT}/dashboard/#/workloads?namespace=_all"
SECRET=$(kubectl get secret -n kubernetes-dashboard | grep kubernetes-dashboard-token- | cut -d " " -f 1)
TOKEN=$(kubectl -n kubernetes-dashboard describe secret ${SECRET}  | grep ^token | cut -d " " -f 7)
echo "Kubernetes Dashboard Token: ${TOKEN}"

