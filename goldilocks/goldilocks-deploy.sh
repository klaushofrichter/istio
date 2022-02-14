#!/bin/bash
# this installs goldilocks
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# remove existing installation
./goldilocks-undeploy.sh

echo
echo "==== $0: Deploy goldilocks, chart version ${GOLDILOCKSCHART}"
cat goldilocks-values.yaml.template | envsubst '$GOLDILOCKSPORT' | helm install -f - goldilocks fairwinds-stable/goldilocks --version ${GOLDILOCKSCHART} -n goldilocks --create-namespace

echo
echo "==== $0: Wait for goldilocks to finish deployment"
kubectl rollout status deployment goldilocks-controller -n goldilocks --request-timeout 5m
kubectl rollout status deployment goldilocks-dashboard -n goldilocks --request-timeout 5m
kubectl rollout status deployment goldilocks-vpa-recommender -n goldilocks --request-timeout 5m

echo 
echo "==== $0: Patch Nodeport to ${GOLDILOCKSPORT}"
# doing this because --base-path seems not to work, hence can't use ingress with /goldilocks path.
#   https://github.com/FairwindsOps/goldilocks/issues/185
kubectl patch svc goldilocks-dashboard -n goldilocks --type='json' -p "[{\"op\":\"replace\",\"path\":\"/spec/ports/0/nodePort\",\"value\":${GOLDILOCKSPORT}}]" 

#
# patch the resources for vpa and dashboard
if [ "${RESOURCEPATCH}" == "yes" ]; then

  echo
  echo "==== $0: Patching resources for goldilocks vpa in the Deployment"
  kubectl rollout status deployment goldilocks-vpa-recommender -n goldilocks --request-timeout 5m
  kubectl patch deployment goldilocks-vpa-recommender -n goldilocks -p '{"spec":{"template":{"spec":{"containers":[{"name":"vpa", "resources":{"limits":{"cpu":"100m","memory":"500M"},"requests":{"cpu":"50m","memory":"250M"}}}]}}}}' 

fi

echo 
echo "==== $0: Tag namespaces to be monitored by Goldilocks (\"not labled\" means that these already have been labled)"
all_namespaces=$(kubectl get namespaces -o json)
nsnumber=$(echo "${all_namespaces}" | jq ".items | length")
i=0
while [ ${i} -lt ${nsnumber} ]; do
  ns=$(echo "${all_namespaces}" | jq -r ".items[${i}].metadata.name")
  kubectl label namespace ${ns} goldilocks.fairwinds.com/enabled=true --overwrite
  i=$(( ${i} + 1 )) 
done

