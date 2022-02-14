#!/bin/bash
# this applies the resource specs from a CSV file
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

#
# determine resource filename
RESOURCEFILE="resources.csv"
[ ! -z "$1" ] && RESOURCEFILE="$1"

#
# Check if the file exists
[ ! -f ${RESOURCEFILE} ] && echo "Resourcefile ${RESOURCEFILE} does not exist. Exit". && exit 1

#
# Ask the question
read -p "$0 applies ${RESOURCEFILE} to cluster ${CLUSTER}. OK? (y/n) " -n 1 -r
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo
  echo "bailing out..."
  exit 1
fi
echo

i=-1
changed=0
while read -r line 
do

  #
  # ignore first line
  i=$(( ${i} + 1 ))
  [ ${i} == "0" ]  && continue

  #
  # extract the data from the csv file
  # "null" means that the existing value should be removed
  ns=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 1)
  kind=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 2)
  name=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 3)
  container=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 4)
  container_index=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 5)
  replicas=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 6)
  cpu_request=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 7)
  memory_request=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 8)
  cpu_limit=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 9)
  memory_limit=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 10)
  location=$(echo ${line} | tr -d '[:space:]' | cut -d "," -f 11)

  echo
  echo "==== $0: (${i}): Processing ${kind} ${name} in ${ns}"

  #
  # to use patch properly, we need to know the current state and use add/remove/replace individually
  current_resources=$(kubectl get ${kind} ${name} -n ${ns} -o json | jq .spec.template.spec.containers[${container_index}].resources)
  current_cpu_request=$(echo "${current_resources}" | jq -r .requests.cpu)
  current_memory_request=$(echo "${current_resources}" | jq -r .requests.memory)
  current_cpu_limit=$(echo "${current_resources}" | jq -r .limits.cpu)
  current_memory_limit=$(echo "${current_resources}" | jq -r .limits.memory)
  #echo "COMPARE: $cpu_request->$current_cpu_request $memory_request->$current_memory_request $cpu_limit->$current_cpu_limit $memory_limit->$current_memory_limit"
  echo "existing setting: cpu-request: ${current_cpu_request}, memory-request: ${current_memory_request}, cpu-limit: ${current_cpu_limit}, memory-limit: ${current_memory_limit}"
  echo "requested setting: cpu-request: ${cpu_request}, memory-request: ${memory_request}, cpu-limit: ${cpu_limit}, memory-limit: ${memory_limit}"

  # 
  # is there a difference? (kubectl patch can detect this as well, so this is technically not needed)
  if [ "${cpu_request}" == "${current_cpu_request}" ] && [ "${memory_request}" == "${current_memory_request}" ] && [ "${cpu_limit}" == "${current_cpu_limit}" ] && [ "${memory_limit}" == "${current_memory_limit}" ]; then
    echo "values match already, skipping patch for ${kind} ${name} in ${ns}"
    continue
  fi

  # 
  # do we have any value to set?
  if [ "${cpu_limit}" == "null" ] && [ "${memory_limit}" == "null" ] && [ "${cpu_request}" == "null" ] && [ "${memory_request}" == "null" ]; then

    #
    # all values are null, either remove or do nothing
    if [ "${current_resources}" == "null" ]; then
      echo "No resources to set, nothing to delete for ${kind} ${name} in ${ns}"
      continue
    else
      operation="remove"
      value="{}"
    fi

  else

    #
    # there is at least one value to set, i.e. we add or replace
    if [ "${current_resources}" == "null" ]; then
      operation="add"
    else 
      operation="replace"
    fi

    #
    # determine the value to set for limits
    value=""
    if [ "${cpu_limit}" != "null" ] || [ "${memory_limit}" != "null" ]; then
      value="{\"limits\": {"
      if [ "${cpu_limit}" != "null" ]; then
        value="${value} \"cpu\": \"${cpu_limit}\""
	[ "${memory_limit}" != "null" ] && value="${value}, "
      fi
      if [ "${memory_limit}" != "null" ]; then
        value="${value} \"memory\": \"${memory_limit}\""
      fi
      value="${value} }"
    fi

    #
    # determine the value to set for requests
    if [ "${cpu_request}" != "null" ] || [ "${memory_request}" != "null" ]; then
      if [ "${value}" == "" ]; then
	value="{ \"requests\": {"
      else
	value="${value}, \"requests\": {" 
      fi
      if [ "${cpu_request}" != "null" ]; then
	value="${value} \"cpu\": \"${cpu_request}\""
	[ "${memory_request}" != "null" ] && value="${value}, "
      fi
      if [ "${memory_request}" != "null" ]; then
        value="${value} \"memory\": \"${memory_request}\""
      fi
      value="${value} }"
    fi
    value="${value} }"
  fi

  # escape the quotes
  escaped_value=$(echo "${value}" | sed 's/"/\\"/g')

  # call the patch (no special handling for "remove" is needed, but the output looks better)
  if [ "${operation}" == "remove" ]; then
    echo "patching ${kind} ${name} in ${ns} with ${operation} operation"
    kubectl patch ${kind} ${name} -n ${ns} --type='json' -p="[{ \"op\": \"${operation}\", \"path\": \"/spec/template/spec/containers/${container_index}/resources\"}]"
  else
    echo "patching ${kind} ${name} in ${ns} with ${operation} operation ${value}"
    echo kubectl patch ${kind} ${name} -n ${ns} --type='json' -p="[{ \"op\": \"${operation}\", \"path\": \"/spec/template/spec/containers/${container_index}/resources\", \"value\": ${value}}]"
    kubectl patch ${kind} ${name} -n ${ns} --type='json' -p="[{ \"op\": \"${operation}\", \"path\": \"/spec/template/spec/containers/${container_index}/resources\", \"value\": ${value}}]" 
  fi
  kubectl rollout status ${kind} ${name} -n ${ns} --request-timeout=5m
  changed=$(( ${changed} + 1 ))

done < ${RESOURCEFILE}

echo
echo "==== $0: Summary"
[ "${changed}" == "0" ] && changed="none"
[ "${changed}" == "${i}" ] && changed="all of them"
echo "${i} total resources processed, changes applied to ${changed}."
