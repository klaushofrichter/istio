# Canary Deployment with Istio in Kubernetes
This repository contains sources for a related medium.com article about
[Canary Deployment with Istio in Kubernetes](https://medium.com/p/cfe04c662385).
It is demonstrated how to install Istio using Helm Charts and how to set up a Canary deployment.

There are scripts, NodeJS code and yaml files in this repository. Before running this, your should read the [article](https://medium.com/p/cfe04c662385) and inspect the sources. 

The softare is intended for educational and learning purposes only, and you are invited to change anything.
Below is a list of components, and a reference to some more explanation. Please note that the software evolves over
time and some details of the earlier documentation may not match the latest version of the software. Please
note that previouse software releases are not necessarily maintained. 

## More Details
*The content below is under construction, and right now a bit thin on substance.*

## Installation
This software is intended to run on Linux, either Ubuntu or Windows Susbsystem for Linux. 
You will need to install certain software (see below), and then run ./start.sh from the
repository.

### Ubuntu
Follow the instructions for these components: 

* K3D - https://k3d.io
* Docker - https://docs.docker.com/engine/install/ubuntu/ 
* Node JS - https://nodejs.org/en/download/
* helm - https://helm.sh/docs/intro/install/
* jq - https://stedolan.github.io/jq/

After installing the above components, clone the repository and run ./start.sh


### Windows Subsystem for Linux
Follow the instructions in the [article about WSL](https://klaushofrichter.medium.com/using-windows-subsystem-for-linux-for-kubernetes-8bd1f5468531)

* WSL - see https://docs.microsoft.com/en-us/windows/wsl/install
* Docker Desktop - see https://docs.docker.com/desktop/windows/wsl

After installing the above components, open a WSL terminal, clone the repository
and run ./setup.sh to install remaining tools. Then run ./setup.sh in the terminal to launch the cluster. 


## Software Components
These software componentes are part of the overall system.

### K3D 
* ./setup.sh - installs various components, such as docker and K3d.
* ./config.sh - configures the whole systema.
* ./start.sh - recreates the clsuter based on the configuration.
* ./slack.sh - sends slack messages to the configured channel.
* ./k3d-config.yaml.template - configures the K3D Cluster.
* ./config.sh - configures the whole system.

### ingress-nginx
* ./ingress-nginx-deploy.sh - installs ingress-nginx
* ./ingress-nginx-undeploy.sh - uninstalls ingress-nginx

### app
* ./app-build.sh - builds the NodeJS application
* ./app-deploy.sh - installs the NodeJS application
* ./app-undeploy.sh - uninstalls the NodeJS application
* ./app-update.sh - updates the image of an existing deployment
* ./app-traffic.sh - creates API calls to the application
* ./app-canary.sh - sets the distribution between two application deployments
* ./app-canary-status.sh - show the current distribution of calls between two application deployments
* ./app-scale.sh - sets the number of replicas in a deployment

### prom
* ./prom-deploy.sh - installs Kube-Prometheus-stack (Prometheus, Alertmanager, Grafana)
* ./prom-undeploy.sh - uninstalls Kube-Prometheus-stack

### fluentbit
* ./fluentbit-deploy.sh - installs fluentbit
* ./fluentbit-undeploy.sh - uninstalls fluentbit

### influxdb
* ./influxdb-deploy.sh - installs InfluxDB
* ./influxdb-undeploy.sh - uninstalls InfluxDB

### nginx
Optional. Related flag in config.sh: NGINX_ENABLE
* ./nginx-deploy.sh - installs Nginx
* ./nginx-undeploy.sh - uninstalls Nginx
* ./nginx-index.sh - creates the index file with version information

### istio
Optional. Related flag in config.sh: ISTIO_ENABLE
* ./istio-deploy.sh - installs Istio
* ./istio-undeploy.sh - uninstalls Istio

### kubernetes-dashboard
Optional. Related flag in config.sh: KUBERNETES_DASHBOARD_ENABLE
* ./kubernetes-dashboard-deploy.sh - installs the Kubernetes Dashboard
* ./kubernetes-dashboard-undeploy.sh - uninstalls the Kubernetes Dashboard

### resources
Optional. Related flag in config.sh: RESOURCEPATCH
* ./resource-get.sh - retrieves current resource setting and creates a resource file
* ./resource-check.sh - runs some analysis on a resource file
* ./resource-apply.sh - writes resource settings file to the current cluster

### goldilocks
Optional. Related flag in config.sh: GOLDILOCKS_ENABLE
* ./goldilocks-deploy.sh - installs Goldilocks
* ./goldilocks-undeploy.sh - uninstalls Goldilocks
* ./goldilocks-recommendation.sh - extracts two resource files (see resources above) from Goldilocks

### keda
Optional. Related flag in config.sh: KEDA_ENABLE. Disabled when HPA_ENABLE is "yes"
* ./keda-deploy.sh - installs Keda
* ./keda-undeploy.sh - uninstalls Keda

### grafana-cloud 
Optional. Related flag in config.sh: GRAFANA_CLOUD_ENABLE
* ./grafana-cloud/grafana-cloud-deploy.sh - installs Grafana Cloud
* ./grafana-cloud/grafana-cloud-undeploy.sh - uninstalls Grafana Cloud

