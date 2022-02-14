#!/bin/bash
# this uninstalls kube-prometheus-stack 
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# Delete prometheus installation and namespace if namespace is present
if [[ ! -z $(kubectl get namespace | grep "^monitoring" ) ]]; then

  echo
  echo "==== $0: Helm uninstall release (this may fail)"
  helm uninstall prom -n monitoring || true

  echo 
  echo "==== $0: Check if webhooks admissions for kube-prometheus can be deleted"
  unset FOUNDONE
  items=$(kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io -o json | jq '.items | length')
  while [ $items -gt 0 ]; do
    items=$(( ${items} - 1 ))
    name=$(kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io -o json | jq -r ".items[${items}].metadata.name")
    indicator="$(echo ${name} | cut -d '-' -f2)-$(echo ${name} | cut -d '-' -f3)"
    if [[ ${indicator} == "kube-prometheus" ]]; then
      echo "validatingwebhookconfigurations \"${name}\" to be deleted..."
      kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ${name}
      FOUNDONE="yes"
    else
      echo "validatingwebhookconfigurations \"${name}\" stays..."
      FOUNDONE="yes"
    fi
  done
  [ -z ${FOUNDONE} ] && echo "no webhook admission present."

  echo 
  echo "==== $0: Check if MutatingWebhookConfiguration for kube-prometheus can be deleted"
  unset FOUNDONE
  items=$(kubectl get MutatingWebhookConfiguration -o json | jq '.items | length')
  while [ $items -gt 0 ] 
  do
    items=$(( ${items} - 1 ))
    name=$(kubectl get MutatingWebhookConfiguration -o json | jq -r ".items[${items}].metadata.name")
    indicator="$(echo ${name} | cut -d '-' -f2)-$(echo ${name} | cut -d '-' -f3)"
    if [[ ${indicator} == "kube-prometheus" ]]; then
      echo "MutatingWebhookConfiguration \"${name}\" to be deleted"
      kubectl delete MutatingWebhookConfiguration ${name}
      FOUNDONE="yes"
    else
      echo "MutatingWebhookConfiguration \"${name}\" stays"
      FOUNDONE="yes"
    fi
  done
  [ -z ${FOUNDONE} ] && echo "no Mutating Webhook Configuration present."

  echo
  echo "==== $0: Remove dashboards (this may fail)"
  kubectl delete configmap ${APP}-dashboard-configmap -n monitoring || true
  kubectl delete configmap ingress-nginx-dashboard -n monitoring || true
  kubectl delete configmap ingress-nginx-perf-dashboard -n monitoring || true
  kubectl delete configmap fluentbit-dashboard -n monitoring || true
  kubectl delete configmap influxdb-dashboard -n monitoring || true

  echo
  echo "==== $0: Delete namespace \"monitoring\" (this may take a while)"
  kubectl delete namespace monitoring
else
  echo
  echo "==== $0: Namespace \"monitoring\" does not exist"
  echo "nothing to do."
fi

