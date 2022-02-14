#!/bin/bash
# this creates an index.html file in nginx-html
# this is quite complex and pretty much not maintainable :-(

set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1
DIR="nginx-html"

#
# Set the port that is used for the app... the only ISTIO routed service at this time is the nodejs app
APPPORT=${HTTPPORT}
[ "${ISTIO_ENABLE}" == "yes" ] && APPPORT=${ISTIOPORT}

echo
echo "==== $0: Gathering Version Information"
DATE=$(date +%m/%d/%Y,\ %I:%M:%S\ %p\ +%Z)
echo "Snapshot taken at ${DATE}"

# system components
K3D=$(k3d version | grep k3d | cut -d " " -f 3)
K3S=$(k3d version | grep k3s | cut -d " " -f 3)
KUBERNETES=$(kubectl version -o json | jq -rj '.serverVersion | .gitVersion' | cut -d "+" -f 1)
KUBECTL=$(kubectl version -o json | jq -rj '.clientVersion | .gitVersion' | cut -d "+" -f 1)
DOCKER=$(docker version --format '{{.Server.Version}}')

# helm and helm charts
HELM=$(helm version | cut -d '"' -f 2)
HELMRELEASES=$(helm list -A)
GOLDILOCKSHELM=$(echo "${HELMRELEASES}" | grep "^goldilocks" | awk -F ' ' '{print $9}' | cut -d "-" -f 2)
PROMHELM=$(echo "${HELMRELEASES}" | grep "^prom" | awk -F ' ' '{print $9}' | cut -d "-" -f 4)
INFLUXDBHELM=$(echo "${HELMRELEASES}" | grep "^influxdb" | awk -F ' ' '{print $9}' | cut -d "-" -f 2 )
FLUENTBITHELM=$(echo "${HELMRELEASES}" | grep "^fluentbit" | awk -F ' ' '{print $9}' | cut -d "-" -f 3)
NGINXHELM=$( echo "${HELMRELEASES}" | grep "^nginx" | awk -F ' ' '{print $9}' | cut -d "-" -f 2)
INGRESSNGINXHELM=$( echo "${HELMRELEASES}" | grep "^ingress-nginx" | awk -F ' ' '{print $9}' | cut -d "-" -f 3)
KEDAHELM=$( echo "${HELMRELEASES}" | grep "^keda" | awk -F ' ' '{print $9}' | cut -d "-" -f 2)
DASHBOARDHELM=$( echo "${HELMRELEASES}" | grep "^kubernetes-dashboard" | awk -F ' ' '{print $9}' | cut -d "-" -f 3)
ISTIODHELM=$( echo "${HELMRELEASES}" | grep "^istiod" | awk -F ' ' '{print $9}' | cut -d "-" -f 2)
ISTIOBASEHELM=$( echo "${HELMRELEASES}" | grep "^istio-base" | awk -F ' ' '{print $9}' | cut -d "-" -f 2)
ISTIOGATEWAYHELM=$( echo "${HELMRELEASES}" | grep "^istio-gateway" | awk -F ' ' '{print $9}' | cut -d "-" -f 2)

# apps
POD=$(kubectl get pods -n istio-system --ignore-not-found | grep "^istiod-" | cut -d " " -f 1)
[ ! -z "${POD}" ] && ISTIODISCOVERY=$( kubectl exec -n istio-system ${POD} -- /usr/local/bin/pilot-discovery version  | cut -d '"' -f 2)
POD=$(kubectl get pods -n istio-gateway --ignore-not-found | grep "^istio-" | cut -d " " -f 1)
[ ! -z "${POD}" ] && ISTIOPILOT=$(kubectl exec -n istio-gateway ${POD} -- /usr/local/bin/pilot-agent version 2>&1  | cut -d '"' -f 2)
[ ! -z "${POD}" ] && ISTIOENVOY=$(kubectl exec -n istio-gateway ${POD} -- /usr/local/bin/envoy --version 2>&1  | tr -d "\n" | cut -d "/" -f 6)

#POD=$(kubectl get pods -n goldilocks --ignore-not-found | grep "^goldilocks-dashboard" | cut -d " " -f 1)
#GOLDILOCKS=$(kubectl exec -n goldilocks ${POD} -- ./goldilocks version 2>&1 | cut -d ":" -f 2 | cut -d " " -f 1 )
GOLDILOCKS=$( kubectl get pod -n goldilocks -o json | jq -r '.items[0] | select( .kind=="Pod") | .spec.containers[] | select( .name=="goldilocks") | .image' | cut -d ":" -f 2 )
VPARECOMMENDER=$( kubectl get pod -n goldilocks -o json | jq -r '.items[] | select( .kind=="Pod") | .spec.containers[] | select( .name=="vpa") | .image' | cut -d ":" -f 2 )

PROMETHEUS=$(kubectl exec -n monitoring prometheus-prom-kube-prometheus-stack-prometheus-0 -- prometheus --version 2>&1 | grep "^prometheus" | cut -d " " -f 3)
ALERTMANAGER=$(kubectl exec -n monitoring alertmanager-prom-kube-prometheus-stack-alertmanager-0 -- alertmanager --version 2>&1 | grep "^alertmanager" | cut -d " " -f 3)
POD=$(kubectl get pod -n monitoring | grep "^prom-grafana-" | cut -d " " -f 1)
GRAFANA=$(kubectl exec -n monitoring ${POD} -c grafana -- grafana-server -v 2>&1  | cut -d " " -f 2)

POD=$(kubectl get pods -n influxdb | grep "^influxdb-0" | cut -d " " -f 1)
[ ! -z "${POD}" ] && INFLUXDBSHELL=$(kubectl exec -n influxdb ${POD} -- influx --version | cut -d " " -f 4 | sed 's/.$//')
[ ! -z "${POD}" ] && INFLUXDB=$(kubectl exec -n influxdb ${POD} -- influxd version | cut -d " " -f 2)
POD=$(kubectl get pods -n influxdb | grep "^influxdb-stats-exporter" | cut -d " " -f 1)
# below: this is not the version but the build date. Version is not available.
INFLUXDBEXPORTER=$(kubectl exec -n influxdb ${POD} -- /influxdb_stats_exporter --version 2>&1 | grep "  build date:" | tr -d " " | cut -d ":" -f 2)
INFLUXDBUI=$( kubectl get pod -n influxdb -o json | jq -r '.items[] | select( .kind=="Pod") | .spec.containers[] | select( .name=="influxdb-ui-container") | .image' | cut -d ":" -f2 )

POD=$(kubectl get pods -n fluentbit -l "app.kubernetes.io/name=fluent-bit,app.kubernetes.io/instance=fluentbit" -o jsonpath="{.items[0].metadata.name}")
[ ! -z "${POD}" ] && FLUENTBIT=$(kubectl exec ${POD} -n fluentbit -- /fluent-bit/bin/fluent-bit --version | cut -d " " -f 3)

POD=$(kubectl get pods -n ingress-nginx | grep "^ingress-nginx-controller-" | cut -d " " -f 1)
[ ! -z "${POD}" ] && INGRESSNGINXNGINX=$(kubectl exec -n ingress-nginx ${POD} -- nginx -v 2>&1 | cut -d "/" -f 2)
INGRESSNGINX=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o json | jq -r .metadata.labels.\"app.kubernetes.io/version\")

POD=$(kubectl get pods -n nginx | grep "^nginx" | head -n1 | cut -d " " -f 1)
[ ! -z "${POD}" ] && NGINX=$(kubectl exec ${POD} -n nginx -c nginx -- /opt/bitnami/nginx/sbin/nginx -v 2>&1 | cut -d "/" -f 2 )

DASHBOARD=$( kubectl get pod -n kubernetes-dashboard -o json | jq -r '.items[] | select( .kind=="Pod") | .spec.containers[] | select( .name=="kubernetes-dashboard") | .image' | cut -d ":" -f 2 )
KEDA=$( kubectl get pod -n keda -o json | jq -r '.items[] | select( .kind=="Pod") | .spec.containers[] | select( .name=="keda-operator") | .image' | cut -d ":" -f2 )
POD=$(kubectl get pods -n grafana-cloud --ignore-not-found | grep "^grafana-agent" | cut -d " " -f 1)
[ ! -z "${POD}" ] && GRAFANACLOUDAGENT=$(kubectl exec ${POD} -n grafana-cloud -- /bin/agent --version 2>&1 | grep "^agent" | cut -d " " -f 3)

MYAPP=$(curl -s http://localhost:${APPPORT}/service/info | jq -r .serverVersion)

# TODO: more apps can be done...

echo "Done gathering Version Information."

echo
echo "==== $0: Generating ${DIR}/index.html"
mkdir -p ${DIR}
{
echo "<html>"
echo "<head>"
echo "  <title>${CLUSTER} Springboard</title>"
echo "  <style>"
echo "    .disable { color: LightGray; }"
echo "    .disable a:link { color: LightGray; }"
echo "    .disable a:visited { color: LightGray; }"
echo "    .disable a:hover { color: LightGray; }"
echo "    .disable a:active { color: LightGray; }"
echo "  </style>"
echo "</head>"
echo "<body>"
echo "<h1>${CLUSTER} Springboard</h1>"
echo "This is a static HTML page, generated at <i>${DATE}</i>. Update this page by running <b>./nginx-index.sh</b>"
echo "<br>Run this before using kubectl: <b>export KUBECONFIG=~${KUBECONFIG:${#HOME}}</b></li>"

echo "<h2>Entry Points</h2>"
if [ -z "${DASHBOARDHELM}" ] || [ ! "${GRAFANA_CLOUD_ENABLE}" == "yes" ] || [ -z ${GOLDILOCKSHELM} ] || [ -z ${NGINX_ENABLE} ] || [ -z ${DASHBOARDHELM} ]; then 
  echo "Features that are disabled at the time of page generation are grayed out and likely not working."
fi
echo "<ul>"
[ -z "${DASHBOARDHELM}" ] && echo "  <div class=\"disable\">"
  echo "  <li><a href=\"http://localhost:${HTTPPORT}/dashboard/#/workloads?namespace=_all\"><b>Kubernetes Dashboard</b></a>"
  # Retrieve Kubernetes Dashboard Token if available
  SECRET=$(kubectl get secret -n kubernetes-dashboard --ignore-not-found | grep kubernetes-dashboard-token- | cut -d " " -f 1)
  if [ ! -z ${SECRET} ]; then
    TOKEN=$(kubectl -n kubernetes-dashboard describe secret ${SECRET}  | grep ^token | cut -d " " -f 7)
    echo "${TOKEN}" > ${DIR}/kubernetes-dashboard-token.txt
    echo " (<a href=\"kubernetes-dashboard-token.txt\">token</a> at the time of page generation)"
  fi
echo "</li>"
[ -z "${DASHBOARDHELM}" ] && echo "  </div>"
echo "  <li>NodeJS App ${APP} APIs: <a href=\"http://localhost:${APPPORT}/service/info\"><b>info</b></a>, "
echo "  <a href=\"http://localhost:${APPPORT}/service/random\"><b>random</b></a>, "
echo "  <a href=\"http://localhost:${APPPORT}/service/metrics\"><b>metric</b></a> "
if [ ${APPPORT} == ${HTTPPORT} ]; then
  echo "(NodeJS application is routed through <b>Ingress-Nginx</b>)"
else
  echo "(NodeJS application is routed through <b>Istio Gateway</b>. A secondary route through ingress-nginx is available: "
  echo " <a href=\"http://localhost:${HTTPPORT}/service/info\"><b>info</b></a>, "
  echo " <a href=\"http://localhost:${HTTPPORT}/service/random\"><b>random</b></a>, "
  echo " <a href=\"http://localhost:${HTTPPORT}/service/metrics\"><b>metric</b></a>)"
fi
echo "  </li>"
echo "  <li>Kube-Prometheus-Stack: <a href=\"http://localhost:${HTTPPORT}/grafana/?orgId=1\"><b>Grafana</b></a> (use admin/${GRAFANA_LOCAL_ADMIN_PASS} to login, change password in <i>config.sh</i>),"
echo " <a href=\"http://localhost:${HTTPPORT}/prom/targets\"><b>Prometheus</b></a>, "
echo " <a href=\"http://localhost:${HTTPPORT}/alert\"><b>Alertmanager</b></a>"
echo "  <ul>"
echo "  <li>Selected Grafana Dashboards: "
echo "  <a href=\"http://localhost:8080/grafana/d/efa86fd1d0c121a26444b636a3f509a8/kubernetes-compute-resources-cluster?orgId=1&refresh=10s\"><b>Cluster Compute</b></a> - "
echo "  <a href=\"http://localhost:8080/grafana/d/myapp-2022-01-07-influx/myapp-application-information?orgId=1&refresh=10s\"><b>${APP} Information</b></a> - "
echo "  <a href=\"http://localhost:8080/grafana/d/2022-01-07-scale/myapp-scale-demonstration?orgId=1&refresh=30s\"><b>${APP} Scale</b></a>"
[ "${ISTIO_ENABLE}" == "yes" ] && echo "- <a href=\"http://localhost:8080/grafana/d/myapp-canary-2022-01-31/myapp-canary-monitor?orgId=1&from=now-15m&to=now\"><b>${APP} Canary</b></a>"
echo "  </li>"
echo "  </ul>"
echo "  <li><a href=\"http://localhost:${INFLUXUIPORT}\"><b>InfluxDB UI</b></a>"
echo "  (configure influx server with <i>http://localhost:${INFLUXPORT}</i> in "
echo "  <a href=\"http://localhost:${INFLUXUIPORT}/#/settings/\">settings</a> - user"
echo "  <i>admin</i>, password <i>${INFLUXDB_LOCAL_ADMIN_PASSWORD}</i> - change password in <i>config.sh</i>.</li>"
[ ! "${GRAFANA_CLOUD_ENABLE}" == "yes" ] && echo "  <div class=\"disable\">"
echo "  <li>Grafana Cloud: <a href=\"https://grafana.com/orgs/${GRAFANA_CLOUD_ORG}\"><b>Portal</b></a> (you may need to login at <a href=\"https://grafana.com\">grafana.com<a/> before this direct link to the portal works), "
  echo "<a href=\"https://${GRAFANA_CLOUD_ORG}.grafana.net\"><b>Grafana Instance</b></a></li>"
[ ! "${GRAFANA_CLOUD_ENABLE}" == "yes" ] && echo "  </div>"
[ -z "${GOLDILOCKSHELM}" ] && echo "  <div class=\"disable\">"
echo "<li><a href=\"http://localhost:${GOLDILOCKSPORT}\"><b>Goldilocks</b></a></li>"
[ -z "${GOLDILOCKSHELM}" ] && echo "  </div>"
[ -z "${NGINXHELM}" ] && echo "  <div class=\"disable\">"
echo "  <li><a href=\"http://localhost:${HTTPPORT}/index.html\"><b>Nginx</b></a> (this page)</li>"
[ -z "${NGINXHELM}" ] && echo "  </div>"
echo "</ul>"

echo "<h2>Deployed Versions</h2>"
echo "Versions snapshot taken from the current local environment and the live cluster:" 
echo "<ul>"
echo "<li><b><a href=\"https://k3s.io/\">K3S</a></b>: ${K3S} - <b><a href=\"https://k3d.io/\">K3D</a></b>: ${K3D} - "
echo "<b><a href=\"https://kubernetes.io/\">Kubernetes</a></b>: ${KUBERNETES} - "
echo "<b><a href=\"https://www.docker.com/\">Docker</a></b>: ${DOCKER} - "
echo "<b><a href=\"https://kubernetes.io/docs/reference/kubectl/kubectl/\">kubectl</a></b>: ${KUBECTL} - "
echo "<b><a href=\"https://helm.sh/\">Helm</a></b>: ${HELM}</li>"

echo "<li><b>Helm Charts</b>: "
[ ! -z ${NGINXHELM} ] && echo "<b><a href=\"https://artifacthub.io/packages/helm/bitnami/nginx\">Nginx</a></b>: ${NGINXHELM} - "
[ ! -z ${KEDAHELM} ] && echo "<b><a href=\"https://artifacthub.io/packages/helm/kedacore/keda\">Keda</a></b>: ${KEDAHELM} - "
[ ! -z ${DASHBOARDHELM} ] && echo "<b><a href=\"https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard\">Kubernetes Dashboard</a></b>: ${DASHBOARDHELM} - "
[ ! -z ${GOLDILOCKSHELM} ] && echo "<b><a href=\"https://artifacthub.io/packages/helm/fairwinds-stable/goldilocks\">Goldilocks</a></b>: ${GOLDILOCKSHELM} - "
echo "<b><a href=\"https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack\">Kube-Prometheus-Stack</a></b>: ${PROMHELM} - "
echo "<b><a href=\"https://artifacthub.io/packages/helm/influxdata/influxdb\">InfluxDB</a></b>: ${INFLUXDBHELM} - "
echo "<b><a href=\"https://artifacthub.io/packages/helm/fluent/fluent-bit\">Fluent-Bit</a></b>: ${FLUENTBITHELM} - "
echo "<b><a href=\"https://artifacthub.io/packages/helm/istio-official/istiod\">IstioD</a></b>: ${ISTIODHELM} - "
echo "<b><a href=\"https://artifacthub.io/packages/helm/istio-official/base\">Istio-Base</a></b>: ${ISTIOBASEHELM} - "
echo "<b><a href=\"https://artifacthub.io/packages/helm/istio-official/gateway\">Istio-Gateway</a></b>: ${ISTIOGATEWAYHELM} - "
echo "<b><a href=\"https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx\">Ingress-Nginx</a></b>: ${INGRESSNGINXHELM}</li>"

echo "<li><b>Apps</b>: "
[ ! -z "${GOLDILOCKS}" ] && echo "<a href=\"https://github.com/FairwindsOps/goldilocks\"><b>Goldilocks</b></a>: ${GOLDILOCKS} - "
[ ! -z "${VPARECOMMENDER}" ] && echo "<a href=\"https://github.com/FairwindsOps/goldilocks\"><b>Goldilocks VPA Recommender</b></a>: ${VPARECOMMENDER} - "
echo "<a href=\"https://prometheus.io/\"><b>Prometheus</b></a>: ${PROMETHEUS} - "
echo "<a href=\"https://grafana.com/\"><b>Grafana</b></a>: ${GRAFANA} - "
echo "<a href=\"https://prometheus.io/docs/alerting/latest/alertmanager/\"><b>Alertmanager</b></a>: ${ALERTMANAGER} - "
echo "<a href=\"https://www.influxdata.com/\"><b>InfluxDB</b></a>: ${INFLUXDB} - "
echo "<a href=\"https://www.influxdata.com/\"><b>InfluxDB Shell</b></a>: ${INFLUXDBSHELL} - "
echo "<a href=\"https://github.com/prometheus/influxdb_exporter\"><b>InfluxDB Stats Exporter</b></a>: ${INFLUXDBEXPORTER} - "
echo "<a href=\"https://github.com/danesparza/influxdb-ui\"><b>InfluxDB UI</b></a>: ${INFLUXDBUI} - "
echo "<a href=\"https://fluentbit.io/\"><b>Fluent-bit</b></a>: ${FLUENTBIT} - "
echo "<a href=\"https://kubernetes.github.io/ingress-nginx/\"><b>Ingress-Nginx</b></a>: ${INGRESSNGINX} - "
echo "<a href=\"https://kubernetes.github.io/ingress-nginx/\"><b>Ingress-Nginx Nginx</b></a>: ${INGRESSNGINXNGINX} - "
echo "<a href=\"https://www.nginx.com/\"><b>Nginx</b></a>: ${NGINX} - "
[ ! -z "${DASHBOARD}" ] && echo "<a href=\"https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/\"><b>Kubernetes Dashboard</b></a>: ${DASHBOARD} - "
[ ! -z "${KEDA}" ] && echo "<a href=\"https://keda.sh/\"><b>Keda</b></a>: ${KEDA} - "
[ ! -z "${GRAFANACLOUDAGENT}" ] && echo "<a href=\"https://grafana.com/docs/grafana-cloud/agent/\"><b>Grafana Cloud Agent</b></a>: ${GRAFANACLOUDAGENT} - "
[ ! -z "${ISTIOPILOT}" ] && echo "<a href=\"https://istio.io/latest/docs/reference/commands/pilot-agent/\"><b>Istio Pilot Agent</b></a>: ${ISTIOPILOT} - "
[ ! -z "${ISTIOENVOY}" ] && echo "<a href=\"https://istio.io/latest/docs/ops/deployment/architecture/#envoy\"><b>Istio Envoy</b></a>: ${ISTIOENVOY} - "
[ ! -z "${ISTIODISCOVERY}" ] && echo "<a href=\"https://istio.io/latest/docs/reference/commands/pilot-discovery/\"><b>Istio Pilot Discovery</b></a>: ${ISTIODISCOVERY} - "
echo "<a href=\"https://klaushofrichter.medium.com/aeeddc6ebb93\"><b>NodeJS app</b></a>: ${MYAPP}</li>"
echo "</ul>"

echo "<h2>Feature Settings</h2>"
echo "The settings are controlled in the file <b>config.sh</b>"
echo "<ul>"
echo "  <li>SLACK_ENABLE: <b>${SLACK_ENABLE}</b> - controls if Slack is used for alerting. "
echo " <a href=\"https://klaushofrichter.medium.com/laymens-guide-to-alerts-with-kubernetes-and-alertmanager-5fa175dbf98b\">Slack account configuration</a> is required.</li>"
echo "  <li>GRAFANA_CLOUD_ENABLE: <b>${GRAFANA_CLOUD_ENABLE}</b> - controls if grafana-cloud is deployed. "
echo " <a href=\"https://klaushofrichter.medium.com/migrating-to-grafana-cloud-653dabd5a8b8\">Grafana Cloud account configuration</a> is required.</li>"
echo "  <li>GOLDILOCKS_ENABLE: <b>${GOLDILOCKS_ENABLE}</b> - controls if goldilocks is deployed.</li>"
echo "  <li>KUBERNETES_DASHBOARD_ENABLE: <b>${KUBERNETES_DASHBOARD_ENABLE}</b> - controls if Kubernetes Dashboard is deployed.</li>"
echo "  <li>KEDA_ENABLE: <b>${KEDA_ENABLE}</b> - controls if keda is deployed.</li>"
echo "  <li>HPA_ENABLE: <b>${HPA_ENABLE}</b> - controls if HPA is deployed. This will disable KEDA_ENABLE.</li>"
echo "  <li>NGINX: <b>${NGINX_ENABLE}</b> - controls if nginx is deployed.</li>"
echo "  <li>ISTIO_ENABLE: <b>${ISTIO_ENABLE}</b> - controls if Istio is deployed.</li>"
echo "  <li>RESOURCEPATCH: <b>${RESOURCEPATCH}</b> - controls if resource settings are patched everywhere.</li>"
echo "</ul>"

echo "<h2>Medium Articles</h2>"
echo "See also <a href=\"https://klaushofrichter.medium.com/\">Medium.com</a> for a live listing. See also the"
echo "Github repository for source <a href=\"https://github.com/klaushofrichter/istio\">here</a>."
echo "<ul>"
echo "  <li><a href=\"https://medium.com/p/cfe04c662385\">Canary Deployment with Istio in Kubernetes</a></li>"
echo "  <li><a href=\"https://medium.com/p/d4e44c4d7d71\">Nginx Deployment with Helm</a></li>"
echo "  <li><a href=\"https://klaushofrichter.medium.com/kubernetes-dashboard-deployment-one-more-time-75557119ca2c\">Kubernetes Dashboard Deployment &#8211; one more time</a></li>"
echo "  <li><a href="https://klaushofrichter.medium.com/readyz-and-livez-getting-started-with-kubernetes-health-endpoints-using-nodejs-express-aeeddc6ebb93">readyz and livez: Getting started with Kubernetes health endpoints using NodeJS/Express</a></li>"
echo "  <li><a href=\"https://klaushofrichter.medium.com/autoscaling-with-keda-70e5b12be492\">Autoscaling with Keda</a></li>"
echo "  <li><a href=\"https://klaushofrichter.medium.com/kubernetes-resource-setting-in-a-local-k3d-cluster-6709cd5cee2c\">Kubernetes Resource Setting in a local K3D Cluster</a></li>"
echo "  <li><a href=\"https://klaushofrichter.medium.com/using-windows-subsystem-for-linux-for-kubernetes-8bd1f5468531\">Using Windows Subsystem for Linux for Kubernetes</a></li>"
echo "  <li><a href=\"https://klaushofrichter.medium.com/migrating-to-grafana-cloud-653dabd5a8b8\">Migrating to Grafana Cloud</a></li>"
echo "  <li><a href=\"https://klaushofrichter.medium.com/fluent-bit-influxdb-grafana-on-k3d-1bab51495bd9\">Fluent-bit, InfluxDB, Grafana on K3D</a></li>"
echo "  <li><a href=\"https://klaushofrichter.medium.com/ingress-nginx-metrics-on-grafana-k3d-84dc48374869\">ingress-nginx Metrics on Grafana/K3D</a></li>"
echo "  <li><a href=\"https://klaushofrichter.medium.com/laymens-guide-to-alerts-with-kubernetes-and-alertmanager-5fa175dbf98b\">Laymen&#39;s Guide to Alerts with Kubernetes and Alertmanager</a></li>"
echo "  <li><a href=\"https://klaushofrichter.medium.com/k3d-metrics-for-lens-f60f7bcc4d4f\">K3D Metrics for Lens</a></li>"
echo "</ul>"
echo "</body>"
echo "</html>"
}> ${DIR}/index.html
echo "Done generating ${DIR}/index.html."

if [ -f runbook.html ]; then
  echo 
  echo "==== $0: Installing the runbook"
  cp runbook.html ${DIR}/runbook.html
  echo "done."
fi

echo
echo "==== $0: Deploying static site and restart nginx, not waiting for automatic pickup"
kubectl create configmap nginx-html --from-file nginx-html -n nginx -o yaml --dry-run=client | kubectl replace -f -
kubectl rollout restart deployment.apps nginx -n nginx --request-timeout 5m  # restart to acclerate pickup of the new map

echo
echo "==== $0: Wait for full deployment, then check for git static site"
kubectl rollout status deployment.apps nginx -n nginx --request-timeout 5m 
GITSITE=$(kubectl get pod -n nginx -o json | jq -r '.items[] | select( .kind=="Pod") | .spec.containers[] | select( .name=="git-repo-syncer")')
if [ -z "${GITSITE}" ]; then 
  echo "Gitsite is not enabled in nginx-values.yaml.template, ${DIR}/index.html will be served."
else
  echo "Gitsite is enabled in nginx-values.yaml.template, the local HTML file at ${DIR}/index.html will not be served."
fi

