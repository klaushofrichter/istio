#!/bin/bash
# 
# This takes two integer numbers (incl. 0), with constraints:
# Both number 0 is not good (implying that there is no weight whatsoever)
# The total must be 100.
# The numbers are used directly as weights. They don't need to add up to 100, i.e. 1 2 is legal.

set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# Check that Istio is enabled
if [ ! "${ISTIO_ENABLE}" == "yes" ]; then
  echo 
  echo "==== $0: Istio is not enabled in config.sh"
  echo "Edit config.sh to show ISTIO_ENABLE=\"yes\" and preferably restart the cluster"
  exit 1
fi

echo
echo "==== $0: Calculating target weights"
[ $# != 2 ] && echo "need two arguments to apply weight to green and blue. Exit." && exit 1
GREENWEIGHT=$1
BLUEWEIGHT=$2
[ -z "${GREENWEIGHT##*[!0-9]*}" ] && echo "Green weight (first argument) must be a number" && exit 1
[ -z "${BLUEWEIGHT##*[!0-9]*}" ] && echo "Blue weight (second argument) must be a number" && exit 1
[ $(( ${GREENWEIGHT} + ${BLUEWEIGHT} )) != 100 ] && echo "Green weight plus Blue weight should be 100" && exit 1
echo "Target weights: Green: ${GREENWEIGHT} - Blue: ${BLUEWEIGHT}"

#
# Check if services are running
GREENSERVICE="no"
BLUESERVICE="no"
[ ! -z "$(kubectl get svc -n ${APP}-green --ignore-not-found | grep ${APP}-service)" ] && GREENSERVICE="yes"
[ ! -z "$(kubectl get svc -n ${APP}-blue --ignore-not-found | grep ${APP}-service)" ] && BLUESERVICE="yes"

#
# Check if weights can be applied to a respective service
if [ "${GREENWEIGHT}" != "0" ] && [ "${GREENSERVICE}" == "no" ]; then
  echo "Can't apply Green Weight ${GREENWEIGHT} to Green service ${APP}-service because it does not exist"
  echo "To deploy into the Green namespace, use: ./app-deploy.sh ${APP}-green"
  exit 1
fi
if [ "${BLUEWEIGHT}" != "0" ] && [ "${BLUESERVICE}" == "no" ]; then
  echo "Can't apply Blue Weight ${BLUEWEIGHT} to Blue service ${APP}-service because it does not exist"
  echo "To deploy into the Blue namespace, use: ./app-deploy.sh ${APP}-blue"
  exit 1
fi

echo
echo "==== $0: Generating manifest for VirtualService"
cat << EOF > app-virtualservice.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${APP}
  namespace: istio-gateway
spec:
  gateways:
  - istio-gateway/istio-gateway
  hosts:
  - "*"
  http:
  - match:
    - uri:
        prefix: /service
    route:
EOF
if [ ${GREENWEIGHT} != "0" ]; then
cat << EOF >> app-virtualservice.yaml
    - destination:
        host: ${APP}-service.${APP}-green.svc.cluster.local
        port:
          number: 3000 
EOF
[ ${BLUEWEIGHT} != 0 ] && echo "      weight: ${GREENWEIGHT}" >> app-virtualservice.yaml
fi
if [ ${BLUEWEIGHT} != "0" ]; then
cat << EOF >> app-virtualservice.yaml
    - destination:
        host: ${APP}-service.${APP}-blue.svc.cluster.local
        port:
          number: 3000 
EOF
[ ${GREENWEIGHT} != 0 ] && echo "      weight: ${BLUEWEIGHT}" >> app-virtualservice.yaml
fi
echo "done. See app-virtualservice.yaml for the manifest."

echo
echo "==== $0: Applying VirtualService"
#cat app-virtualservice.yaml
kubectl apply -f app-virtualservice.yaml

#echo
#echo "==== $0: Wait for the VirtualService to be ready"
#kubectl wait --for=condition=Reconciled virtualservice/${APP} -n istio-gateway  --timeout 2m

echo "Note that this VirtualService deployment does not change the apps deployment in either namespace"
