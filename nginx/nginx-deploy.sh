#!/bin/bash
# this installs nginx
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# remove existing installation
./nginx-undeploy.sh

echo
echo "==== $0: Deploy nginx / bitnami, chart version ${NGINXCHART}"
cat nginx-values.yaml.template | envsubst | helm install -f - nginx bitnami/nginx --version ${NGINXCHART} -n nginx --create-namespace

#
# label the namespace for Goldilocks
[ "${GOLDILOCKS_ENABLE}" == "yes" ] && kubectl label namespace nginx goldilocks.fairwinds.com/enabled=true --overwrite

echo
echo "==== $0: Create dummy nginx-html config map, to be replaced later to get proper nginx version information."
mkdir -p nginx-html
cp nginx-index.html nginx-html/index.html
kubectl create configmap nginx-html --from-file nginx-html -n nginx

#
# patch resource management if enabled
if [ "${RESOURCEPATCH}" == "yes" ]; then
  echo
  echo "==== $0: Patching nginx repo syncer resource settings into the deployment (this may fail if git-repo-sync is not used)"
  kubectl rollout status deployment.apps nginx -n nginx --request-timeout 5m
  kubectl patch deployment nginx -n nginx -p '{"spec":{"template":{"spec":{"containers":[{"name":"git-repo-syncer","resources":{"limits":{"cpu":"40m","memory":"40Mi"},"requests":{"cpu":"5m","memory":"10Mi"}}}]}}}}' || true
fi

echo
echo "==== $0: Wait for nginx to finish deployment"
kubectl rollout status deployment.apps nginx -n nginx --request-timeout 5m
i=0
echo -n "Wait for nginx ingress to be available.."
while [ "$(kubectl get ing nginx -n nginx -o json | jq -r .status.loadBalancer.ingress[0].ip)" = "null" ]
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
echo "==== $0: generate HTML content file and re-deploy configmap"
echo "Note: this will not be served when the static GIT site is enabled in ./nginx-values.yaml.template"
./nginx-index.sh
