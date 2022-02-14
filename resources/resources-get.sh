#!/bin/bash
# this generates a resource utilization file
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# determine resource filename
RESOURCEFILE="resources.csv"
[ ! -z "$1" ] && RESOURCEFILE="$1"

#
# function to add the resource definition location from resources-location.json 
function add-location() {
  i=0;
  while read -r line
  do
    i=$(( ${i} + 1 ))
    [ ! -f resources-location.json ] && echo "$line" && continue    # do nothing if resources-location.json is not there
    [ "${i}" == "1" ] && echo "${line}, location-hint" && continue  # process first line
    ns=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 1)
    name=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 3)
    container_name=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 4)
    location=$( cat resources-location.json | jq -r ".[] | select(.ns == \"${ns}\") | .resource[] | select(.name == \"${name}\") | .containers[] | select( .\"container-name\" == \"${container_name}\") | .location" )
    echo "$line, $location"
  done
}

#
# Check if the file exists and ask the question
if [[ -f ${RESOURCEFILE} ]]; then
  read -p "Resourcefile ${RESOURCEFILE} exists and will be overwritten. OK? (y/n) " -n 1 -r
  if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    echo
    echo "bailing out..."
    exit 1
  fi
fi
echo

echo
echo "==== $0: Creating resource file ${RESOURCEFILE}"
kubectl get deployment,daemonset,statefulset --all-namespaces -o go-template-file=./resources.go | add-location | (sed -u 1q; sort) > ${RESOURCEFILE}
echo "done."

echo 
echo "==== $0: Showing Resource table"
cat ${RESOURCEFILE} | sed 's/,/ ,/g' | column -t -s, 

