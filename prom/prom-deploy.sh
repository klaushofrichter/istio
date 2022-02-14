#!/bin/bash
# this installs kube-prometheus-stack
# https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[[ -z "${KUBECONFIG}" ]] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# remove existing prometheus installation
./prom-undeploy.sh

echo
echo "==== $0: Install prometheus-community stack, chart ${KUBEPROMETHEUSSTACKCHART}"
export SLACK_OR_NULL="null"
if [ "${SLACK_ENABLE}" == "yes" ]; then
  echo "Slack config is enabled"
  SLACK_RECEIVER_CONFIG="am-values-slack.yaml.template"
  export SLACK_OR_NULL="slack"
fi
unset PROM_ISTIO_VALUES
if [ "${ISTIO_ENABLE}" == "yes" ]; then
  echo "Istio config is enabled"
  PROM_ISTIO_VALUES="prom-values-istio.yaml.template"
fi
cat prom-values.yaml.template ${PROM_ISTIO_VALUES} am-values.yaml.template ${SLACK_RECEIVER_CONFIG} | \
  envsubst "${ENVSUBSTVAR}" | helm install --values - prom \
  prometheus-community/kube-prometheus-stack --version ${KUBEPROMETHEUSSTACKCHART} -n monitoring --create-namespace

#
# label the namespace for Goldilocks
[ "${GOLDILOCKS_ENABLE}" == "yes" ] && kubectl label namespace monitoring goldilocks.fairwinds.com/enabled=true --overwrite

#
# Patch resources when requested for Grafana Sidecars
if [ "${RESOURCEPATCH}" == "yes" ]; then
  echo
  echo "==== $0: Patching resources for grafana side cars resource settings into the Deployment"
  kubectl rollout status deployment.apps prom-grafana -n monitoring --request-timeout 5m
  kubectl patch deployment prom-grafana -n monitoring -p '{"spec":{"template":{"spec":{"containers":[{"name":"grafana-sc-dashboard","resources":{"limits":{"cpu":"60m","memory":"100M"},"requests":{"cpu":"5m","memory":"10M"}}}]}}}}' 
  kubectl patch deployment prom-grafana -n monitoring -p '{"spec":{"template":{"spec":{"containers":[{"name":"grafana-sc-datasources","resources":{"limits":{"cpu":"60m","memory":"100M"},"requests":{"cpu":"5m","memory":"10M"}}}]}}}}' 
  
  echo 
  echo "==== $0: Patching resources for prom-prometheus-node-exporter resource settings in the DaemonSet"
  kubectl rollout status daemonset.apps prom-prometheus-node-exporter -n monitoring --request-timeout 5m
  kubectl patch daemonset prom-prometheus-node-exporter -n monitoring -p '{"spec":{"template":{"spec":{"containers":[{"name":"node-exporter", "resources":{"limits":{"cpu":"90m","memory":"500M"},"requests":{"cpu":"30m","memory":"100M"}}}]}}}}'

  echo 
  echo "==== $0: Patching resources for prom-kube-state-metrics resource settings in the Deployment"
  kubectl rollout status deployment.apps prom-kube-state-metrics -n monitoring --request-timeout 5m
  kubectl patch deployment prom-kube-state-metrics -n monitoring -p '{"spec":{"template":{"spec":{"containers":[{"name":"kube-state-metrics", "resources":{"limits":{"cpu":"150m","memory":"1000M"},"requests":{"cpu":"15m","memory":"100M"}}}]}}}}'

  echo 
  echo "==== $0: Patching resources for Prometheus config reloader StatefulSet"
  kubectl rollout status statefulset prometheus-prom-kube-prometheus-stack-prometheus -n monitoring --request-timeout 5m
  kubectl patch statefulset prometheus-prom-kube-prometheus-stack-prometheus -n monitoring -p '{"spec":{"template":{"spec":{"containers":[{"name":"config-reloader", "resources":{"limits":{"cpu":"100m","memory":"50M"},"requests":{"cpu":"50m","memory":"50M"}}}]}}}}'

  echo 
  echo "==== $0: Patching resources for Alertmanger config reloader Deployment"
  kubectl rollout status statefulset alertmanager-prom-kube-prometheus-stack-alertmanager -n monitoring --request-timeout 5m
  kubectl patch statefulset alertmanager-prom-kube-prometheus-stack-alertmanager -n monitoring -p '{"spec":{"template":{"spec":{"containers":[{"name":"config-reloader", "resources":{"limits":{"cpu":"100m","memory":"50M"},"requests":{"cpu":"50m","memory":"50M"}}}]}}}}' 

fi

echo
echo "==== $0: installing app dashboard"
mkdir -p dashboards 
sed -i 's/myapp/${APP}/g' app-dashboard.json.template # not really needed
cat app-dashboard.json.template | envsubst "${ENVSUBSTVAR}" > dashboards/app-dashboard.json
kubectl create configmap ${APP}-dashboard-configmap -n monitoring --from-file="dashboards/app-dashboard.json"
kubectl patch configmap ${APP}-dashboard-configmap -n monitoring -p '{"metadata":{"labels":{"grafana_dashboard":"1"}}}'

echo
echo "==== $0: installing nginx dashboard"
sed -i 's/myapp/${APP}/g' nginx-dashboard.json.template # not really needed
cat nginx-dashboard.json.template | envsubst "${ENVSUBSTVAR}" > dashboards/nginx-dashboard.json
kubectl create configmap nginx-dashboard-configmap -n monitoring --from-file="dashboards/nginx-dashboard.json"
kubectl patch configmap nginx-dashboard-configmap -n monitoring -p '{"metadata":{"labels":{"grafana_dashboard":"1"}}}'

echo
echo "==== $0: installing scale/keda dashboard"
sed -i 's/myapp/${APP}/g' app-scale-dashboard.json.template # not really needed
cat app-scale-dashboard.json.template | envsubst "${ENVSUBSTVAR}" > dashboards/app-scale-dashboard.json
kubectl create configmap app-scale-dashboard-configmap -n monitoring --from-file="dashboards/app-scale-dashboard.json"
kubectl patch configmap app-scale-dashboard-configmap -n monitoring -p '{"metadata":{"labels":{"grafana_dashboard":"1"}}}'

echo
echo "==== $0: installing canary dashboard"
sed -i 's/myapp/${APP}/g' app-canary-dashboard.json.template # not really needed
cat app-canary-dashboard.json.template | envsubst "${ENVSUBSTVAR}" > dashboards/app-canary-dashboard.json
kubectl create configmap app-canary-dashboard-configmap -n monitoring --from-file="dashboards/app-canary-dashboard.json"
kubectl patch configmap app-canary-dashboard-configmap -n monitoring -p '{"metadata":{"labels":{"grafana_dashboard":"1"}}}'

echo
echo "==== $0: installing ingress-nginx dashboards with some customization"
if [ ! -f dashboards/ingress-nginx-dashboard.json ]; then
  wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/grafana/dashboards/nginx.json -O dashboards/ingress-nginx-dashboard.json
  sed -i 's/NGINX Ingress controller/Ingress NGINX controller/g' dashboards/ingress-nginx-dashboard.json
  sed -i 's/   "nginx"/   "nginx", "ingress-nginx"/g' dashboards/ingress-nginx-dashboard.json
fi
kubectl create configmap ingress-nginx-dashboard -n monitoring --from-file="dashboards/ingress-nginx-dashboard.json"
kubectl patch configmap ingress-nginx-dashboard -n monitoring -p '{"metadata":{"labels":{"grafana_dashboard":"1"}}}'
if [ ! -f dashboards/request-handling-performance.json ]; then
  wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/grafana/dashboards/request-handling-performance.json -O dashboards/request-handling-performance.json
  sed -i 's/Request Handling Performance/Ingress NGINX: Request Handling Performance/g' dashboards/request-handling-performance.json
  sed -i 's/"nginx"/"nginx", "ingress-nginx"/g' dashboards/request-handling-performance.json
fi
kubectl create configmap ingress-nginx-perf-dashboard -n monitoring --from-file="dashboards/request-handling-performance.json"
kubectl patch configmap ingress-nginx-perf-dashboard -n monitoring -p '{"metadata":{"labels":{"grafana_dashboard":"1"}}}'

echo
echo "==== $0: installing fluentbit dashboard with some customization"
if [ ! -f dashboards/fluentbit-dashboard.json ]; then
  wget https://raw.githubusercontent.com/fluent/fluent-bit-docs/8172a24d278539a1420036a9434e9f56d987a040/monitoring/dashboard.json -O dashboards/fluentbit-dashboard.json
  sed -i 's/${DS_PROMETHEUS}/Prometheus/g' dashboards/fluentbit-dashboard.json
  sed -i 's/DS_PROMETHEUS/Prometheus/g' dashboards/fluentbit-dashboard.json
  sed -i 's/^  "tags": \[\],/  "tags": \["logging", "fluent-bit"\],/g' dashboards/fluentbit-dashboard.json
fi
kubectl create configmap fluentbit-dashboard -n monitoring --from-file="dashboards/fluentbit-dashboard.json"
kubectl patch configmap fluentbit-dashboard -n monitoring -p '{"metadata":{"labels":{"grafana_dashboard":"1"}}}'

echo
echo "==== $0: installing influx-stats dashboard with some customization"
if [ ! -f dashboards/influxdb-stats-dashboard.json ]; then
  wget https://grafana.com/api/dashboards/5448/revisions/1/download -O dashboards/influxdb-stats-dashboard.json
  sed -i 's/${DS_PROMETHEUS}/Prometheus/g' dashboards/influxdb-stats-dashboard.json
  sed -i 's/DS_PROMETHEUS/Prometheus/g' dashboards/influxdb-stats-dashboard.json
  sed -i 's/^  "tags": \[\],/  "tags": \["logging", "influxdb"\],/g' dashboards/influxdb-stats-dashboard.json
  cat dashboards/influxdb-stats-dashboard.json | jq '.time = { "from": "now-60m", "to": "now" }' > /tmp/influxdb-stats-dashboard.json
  mv /tmp/influxdb-stats-dashboard.json dashboards/influxdb-stats-dashboard.json
fi
kubectl create configmap influxdb-dashboard -n monitoring --from-file="dashboards/influxdb-stats-dashboard.json"
kubectl patch configmap influxdb-dashboard -n monitoring -p '{"metadata":{"labels":{"grafana_dashboard":"1"}}}'

echo 
echo "==== $0: Remove dashboards that don't make sense in this installation"
kubectl delete configmap -n monitoring prom-kube-prometheus-stack-persistentvolumesusage || true

echo 
echo "==== $0: Patch existing dashboards to use browser timezone"
MAPS=$(kubectl get configmaps -l grafana_dashboard=1 -n monitoring | tail -n +2 | awk '{print $1}')
for m in ${MAPS}
do
  echo -n "Processing map ${m}: "
  kubectl get configmap ${m} -n monitoring -o yaml | \
    sed 's/"timezone": ".*"/"timezone": "browser"/g' | \
    kubectl replace -f - -n monitoring
done

echo
echo "==== $0: Wait for everything to roll out"
kubectl rollout status deployment.apps prom-grafana -n monitoring --request-timeout 5m
kubectl rollout status deployment.apps prom-kube-state-metrics -n monitoring --request-timeout 5m
kubectl rollout status deployment.apps prom-kube-prometheus-stack-operator -n monitoring --request-timeout 5m
kubectl rollout status statefulset.apps/alertmanager-prom-kube-prometheus-stack-alertmanager -n monitoring --request-timeout 5m
kubectl rollout status statefulset.apps/prometheus-prom-kube-prometheus-stack-prometheus -n monitoring --request-timeout 5m
kubectl rollout status daemonset.apps/prom-prometheus-node-exporter -n monitoring --request-timeout 5m
echo -n "Wait for prom-grafana ingress to be available.."
while [ "$(kubectl get ing prom-grafana -n monitoring -o json | jq -r .status.loadBalancer.ingress[0].ip)" = "null" ]
do
  i=$[$i+1]
  [ "$i" -gt "60" ] && echo "this took too long... exit." && exit 1
  echo -n "."
  sleep 2
done
sleep 1
echo
echo "done"


#
# handle istio dashboards when istio is enabled
if [ "${ISTIO_ENABLE}" == "yes" ]; then

  echo
  echo "==== $0: Install Istio Dashboards for version ${ISTIOCHART}"
  # see https://istio.io/latest/docs/ops/integrations/grafana/
  GRAFANA_HOST="http://localhost:${HTTPPORT}/grafana"
  GRAFANA_CRED="admin:${GRAFANA_LOCAL_ADMIN_PASS}"
  GRAFANA_DATASOURCE="Prometheus"
  ISTIO_VERSION=${ISTIODCHART}
  for DASHBOARD in 7639 11829 7636 7630 7645; do
    REVISION="$(curl -s https://grafana.com/api/dashboards/${DASHBOARD}/revisions -s | jq ".items[] | select(.description | contains(\"${ISTIO_VERSION}\")) | .revision")"
    curl -s https://grafana.com/api/dashboards/${DASHBOARD}/revisions/${REVISION}/download > /tmp/dashboard.json
    sed -i 's/^  "tags": \[\],/  "tags": \["istio"\],/g' /tmp/dashboard.json
    echo "Importing $(cat /tmp/dashboard.json | jq -r '.title') (revision ${REVISION}, id ${DASHBOARD})..."
    curl -s -k -u "$GRAFANA_CRED" -XPOST \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -d "{\"dashboard\":$(cat /tmp/dashboard.json),\"overwrite\":true, \
         \"inputs\":[{\"name\":\"DS_PROMETHEUS\",\"type\":\"datasource\", \
         \"pluginId\":\"prometheus\",\"value\":\"$GRAFANA_DATASOURCE\"}]}" \
      $GRAFANA_HOST/api/dashboards/import
    echo -e "\nDone\n"
  done

fi
