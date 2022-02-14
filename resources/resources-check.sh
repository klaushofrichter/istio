#!/bin/bash
# this reviews a resource utilization file
set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh

#
# determine resource filename
RESOURCEFILE="resources.csv"
[ ! -z "$1" ] && RESOURCEFILE="$1"

#
# this function converts a value with a unit to a simple number
function convert() {
  unit=$(echo $1 | tr -d '.0123456789')
  number=$(echo $1 | tr -dc '.0123456789')
  case ${unit} in
    E) factor="1e18";;
    P) factor="1e15";;
    T) factor="1e12";;
    G) factor="1e9";;
    M) factor="1e6";;
    k) factor="1000";;
    m) factor="0.001";;
    Ei) factor="1.17319e18";;
    Pi) factor="1.14569e15";;
    Ti) factor="1.09951e12";;
    Gi) factor="1.07374e9";;
    Mi) factor="1048576";;
    Ki) factor="1024";;
    "") factor="1";; # no unit present
    *) echo "bad unit \"${unit}\""
       exit 1
       ;;
  esac
  value=$(awk "BEGIN{printf \"%.3f\", ${number} * ${factor}}")
  echo ${value}
}

echo
echo "==== $0: Processing resource file ${RESOURCEFILE}"
all_null=0
all_null_names=""
i=-1
total_cpu_limit=0
total_memory_limit=0
total_cpu_request=0
total_memory_request=0
while read -r line 
do
 
  #
  # drop the first line
  i=$(( ${i} + 1 ))
  [ ${i} == "0" ]  && continue

  #
  # extract data
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
  
  #
  # check for all values to be null
  if [ "${cpu_limit}" == "null" ] && [ "${memory_limit}" == "null" ] && [ "${cpu_request}" == "null" ] && [ "${memory_request}" == "null" ]; then
    all_null=$(( ${all_null} + 1))
    #all_null_names=" * ${ns}/${name}/${container}$'\n'${all_null_names}" 
    printf -v all_null_names " * ${ns}/${name}/${container}\n${all_null_names}" 
    continue
  fi

  #
  # add up values when present
  if [ "${cpu_limit}" != "null" ]; then
    total_cpu_limit=$( awk "BEGIN{printf \"%.3f\", ${replicas} * $( convert ${cpu_limit} ) + ${total_cpu_limit} }" )
  fi
  if [ "${memory_limit}" != "null" ]; then
    total_memory_limit=$( awk "BEGIN{printf \"%.3f\", ${replicas} * $( convert ${memory_limit} ) + ${total_memory_limit} }" )
  fi
  if [ "${cpu_request}" != "null" ]; then
    total_cpu_request=$( awk "BEGIN{printf \"%.3f\", ${replicas} * $( convert ${cpu_request} ) + ${total_cpu_request} }" )
  fi
  if [ "${memory_request}" != "null" ]; then
    total_memory_request=$( awk "BEGIN{printf \"%.3f\", ${replicas} * $( convert ${memory_request} ) + ${total_memory_request} }" )
  fi

done < ${RESOURCEFILE}

#
# print results
if [ "${all_null}" == "0" ]; then
  echo "All ${i} workloads have at least some resource management"
else
  echo "There are ${all_null} out of ${i} workloads without any resource management"
  [ ! -z "${all_null_names}" ] && echo -n "${all_null_names}"
fi
echo "Total cpu request: ${total_cpu_request} (aka $( awk "BEGIN{printf \"%d\", ${total_cpu_request} * 1000 }")m)"
echo "Total memory request: $( echo ${total_memory_request} | cut -d "." -f 1) (aka $(echo ${total_memory_request} | numfmt --to=iec-i ))"
echo "Total cpu limit: ${total_cpu_limit} (aka $( awk "BEGIN{printf \"%d\", ${total_cpu_limit} * 1000 }")m)"
echo "Total memory limit: $( echo ${total_memory_limit} | cut -d "." -f 1) (aka $(echo ${total_memory_limit} | numfmt --to=iec-i ))"

