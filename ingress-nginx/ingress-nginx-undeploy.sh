#!/bin/bash
# this uninstalls ingress-nginx
set -e
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# Delete ingress-nginx installation and namespace if namespace is present
if [[ ! -z $(kubectl get namespace | grep "^ingress-nginx" ) ]]; then

  echo
  echo "==== $0: Helm uninstall release ingress-nginx (this may fail)"
  helm uninstall ingress-nginx -n ingress-nginx || true

  echo 
  echo "==== $0: Check if webhooks admissions for ingress-nginx can be deleted"
  items=$(kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io -o json | jq '.items | length')
  while [ $items -gt 0 ]; do
    items=$(( ${items} - 1 ))
    name=$(kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io -o json | jq -r ".items[${items}].metadata.name")
    indicator="$(echo ${name} | cut -d '-' -f2)-$(echo ${name} | cut -d '-' -f3)"
    if [[ ${indicator} == "ingress-nginx" ]]; then
      echo "validatingwebhookconfigurations \"${name}\" to be deleted..."
      kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io ${name}
    else
      echo "validatingwebhookconfigurations \"${name}\" remains..."
    fi
  done
  echo "done."

  echo
  echo "==== $0: Delete namespace \"ingress-nginx\" (this may take a while)"
  kubectl delete namespace ingress-nginx

else

  echo
  echo "==== $0: Namespace \"ingress-nginx\" does not exist"
  echo "nothing to do."

fi

