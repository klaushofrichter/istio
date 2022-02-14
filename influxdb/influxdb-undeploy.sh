#!/bin/bash
# this uninstalls influxdb and associated services
set -e
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# Delete influxdb installation and namespace if namespace is present
if [[ ! -z $(kubectl get namespace | grep "^influxdb" ) ]]; then

  echo
  echo "==== $0: Delete influxdb-ui and influxdb-stats-exporter (this may fail)"
  kubectl delete -f influxdb-ui.yaml.template || true
  kubectl delete -f influxdb-stats-exporter.yaml.template || true

  echo
  echo "==== $0: Helm uninstall release (this may fail)"
  helm uninstall influxdb -n influxdb || true

  echo
  echo "==== $0: Delete namespace \"influxdb\" (this may take a while)"
  kubectl delete namespace influxdb

else

  echo
  echo "==== $0: Namespace \"influxdb\" does not exist"
  echo "nothing to do."

fi

