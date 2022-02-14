#!/bin/bash
# this generates two goldilocks recommendations, one for Guaranteed QoS and one for Burstable QoS
set -e
GQOS="goldilocks-gqos.csv"
BQOS="goldilocks-bqos.csv"
LOCATIONFILE="resources-location.json"

[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1

echo
echo "==== $0: Retrieve Goldilocks Dashboard pod"
POD=$(kubectl get pod -n goldilocks | grep "^goldilocks-dashboard" | cut -d " " -f 1) || true
[ -z ${POD} ] && echo "No Goldilocks pod. Is Goldilocks deployed?" && exit 1
echo "Goldilocks Dashboard pod is ${POD}"

echo
echo "==== $0: Retrieve recommendation summary"
RECO=$(kubectl exec ${POD} -n goldilocks -it -- ./goldilocks summary | jq ".Namespaces | to_entries")
nons=$(echo ${RECO} | jq ". | length")
echo "Found ${nons} namespaces"

#
# write the files (always overwrite)
echo "namespace, kind, name, container-name, container-index, replicas, cpu-request, memory-request, cpu-limit, memory-limit, location-hint" > ${GQOS}
echo "namespace, kind, name, container-name, container-index, replicas, cpu-request, memory-request, cpu-limit, memory-limit, location-hint" > ${BQOS}

# loop through the namespaces
n=0
CT=0  # Container counter
while [ ${n} -lt ${nons} ]; do

  # retrieve the namespace name
  ns=$(echo ${RECO} | jq -r ".[${n}].key")

  # loop through the workloads in the current namespace
  WORKLOADS=$(echo ${RECO} | jq ".[${n}].value.workloads | to_entries")
  nowl=$(echo ${WORKLOADS} | jq ". | length")
  w=0
  while [ ${w} -lt ${nowl} ]; do

    kind=$(echo ${WORKLOADS} | jq -r ".[${w}].value.controllerType")
    name=$(echo ${WORKLOADS} | jq -r ".[${w}].value.controllerName")

    # loop through the containers in the workload
    CONTAINERS=$(echo ${WORKLOADS} | jq ".[${w}].value.containers | to_entries")
    noc=$(echo ${CONTAINERS} | jq ". | length")
    c=0
    while [ ${c} -lt ${noc} ]; do

      container_name=$(echo ${CONTAINERS} | jq -r ".[${c}].value.containerName")
      lowerBoundCPU=$(echo ${CONTAINERS} | jq -r ".[${c}].value.lowerBound.cpu")
      lowerBoundMemory=$(echo ${CONTAINERS} | jq -r ".[${c}].value.lowerBound.memory")
      upperBoundCPU=$(echo ${CONTAINERS} | jq -r ".[${c}].value.upperBound.cpu")
      upperBoundMemory=$(echo ${CONTAINERS} | jq -r ".[${c}].value.upperBound.memory")
      targetCPU=$(echo ${CONTAINERS} | jq -r ".[${c}].value.target.cpu")
      targetMemory=$(echo ${CONTAINERS} | jq -r ".[${c}].value.target.memory")
      uncappedTargetCPU=$(echo ${CONTAINERS} | jq -r ".[${c}].value.uncappedTarget.cpu")
      uncappedTargetMemory=$(echo ${CONTAINERS} | jq -r ".[${c}].value.uncappedTarget.memory")

      #
      # retrieve location of the setting from the helper file 
      
      location="none"
      [ -f ${LOCATIONFILE} ] && location=$( cat ${LOCATIONFILE} | jq -r ".[] | select(.ns == \"${ns}\") | .resource[] | select(.name == \"${name}\") | .containers[] | select( .\"container-name\" == \"${container_name}\") | .location" )

      # 
      # get the number of replicas gtom the live cluster
      if [ "${kind}" == "DaemonSet" ]; then
        replicas=$(kubectl get ${kind} ${name} -n ${ns} -o json | jq -r ".status.numberAvailable")
      else
	replicas=$(kubectl get ${kind} ${name} -n ${ns} -o json | jq -r ".spec.replicas")
      fi

      #
      # Write the recommendation
      echo "Processing ${ns}, ${kind}, ${name}, ${container_name}"
      echo "${ns}, ${kind}, ${name}, ${container_name}, ${c}, ${replicas}, ${lowerBoundCPU}, ${lowerBoundMemory}, ${upperBoundCPU}, ${upperBoundMemory}, ${location}" >> ${BQOS}
      echo "${ns}, ${kind}, ${name}, ${container_name}, ${c}, ${replicas}, ${targetCPU}, ${targetMemory}, ${uncappedTargetCPU}, ${uncappedTargetMemory}, ${location}" >> ${GQOS}

      CT=$(( ${CT} + 1 )) 
      c=$(( ${c} + 1 )) 
    done
    w=$(( ${w} + 1 )) 
  done
  n=$(( ${n} + 1 )) 
done

echo
echo "==== $0: Summary"
echo "Generated file ${GQOS} with \"Guaranteed QOS\" recommendation."
echo "Generated file ${BQOS} with \"Burstable QOS\" recommendation."
echo "This includes ${n} namespaces with a total of ${CT} containers.".
echo "The generated files can be applied with \"./resources-apply.sh CSV-FILE\" in the resources folder"
