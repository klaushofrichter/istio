#!/bin/bash
#
# this generates random traffic for the app (this is a good example of overengineering)
#
# Example uses:
# ./app-traffic.sh               # one api call 
# ./app-traffic.sh 0             # continuous calls (end with ctl-c), one each half second
# ./app-traffic.sh 10            # 10 api calls with 0.5 seconds pause between calls
# ./app-traffic.sh 10 10         # 10 api calls with 10 seconds pause between calls
# ./app-traffic.sh 10 10 10      # 10 api calls with 10 to 20 seconds pause between calls
# ./app-traffic.sh 100 0.1 0.9   # 100 api calls with 0.1 to 1 second pause between calls
# ./app-traffic.sh 100 0 2       # 100 api calls with upto 2 seconds pause between calls
# ./app-traffic.sh 10 0 0        # 10 api calls as fast as possible
# ./app-traffic.sh 0 0 1         # continous calls with upto 1 second delay between the calls 
# ./app-traffic.sh 0 0 0         # send as much as possible without break and delay (not a good idea)

set -e
[ -z ${PROJECTHOME} ] && export PROJECTHOME=$(dirname $(pwd))
source ${PROJECTHOME}/config.sh

CALLS="1"    # one call per default
DELAY="0.5"  # half a second delay between API calls. Overwrite with second argument
SPREAD="0"   # additional delay, randomized between 0 and SPREAD seconds
COLS=$(( $(tput cols) - 5 ))

[ ! -z "$1" ] && CALLS=$1
[ ! -z "$2" ] && DELAY=$2
[ ! -z "$3" ] && SPREAD=$3
[ -z "${KUBECONFIG}" ] && echo "KUBECONFIG not defined. Exit." && exit 1
if [ "${CALLS}" = "0" ]; then
  CALLS="infinite"
fi

#
# Silently overwrite HTTPPORT with ISTIOPORT if ISTIO_ENABLE is "ye"
[ "${ISTIO_ENABLE}" == "yes" ] && export HTTPPORT=${ISTIOPORT}

echo
echo -n "==== $0: Generating ${CALLS} API calls to http://localhost:${HTTPPORT}"
[ "${CALLS}" != "1" ] && echo -n " with between ${DELAY}s and $( bc <<< "scale=2; ${DELAY} + ${SPREAD}" )s delay between the calls."
echo
i="1"
while [ true ] 
do
  TOTALDELAY=$( bc <<< "scale=2; ${DELAY} + ${SPREAD} * $RANDOM / 32767" ) 
  RES="$0: $(date '+%H:%M:%S') ${i}/${CALLS}:"
  [ "${CALLS}" != "1" ] && RES="${RES} delay: ${TOTALDELAY}s "
  if [ $(( ${RANDOM} % 2 )) == 0 ]; then
    RES="${RES}$(curl -s http://localhost:${HTTPPORT}/service/info | tr -d '\n')"
  else
    RES="${RES} $(curl -s http://localhost:${HTTPPORT}/service/random | tr -d '\n')"
  fi
  if [ ${#RES} -gt ${COLS} ]; then
    echo "${RES:0:${COLS}}..."
  else
    echo ${RES}
  fi
  i=$(( ${i} + 1 ))
  if [ ${CALLS} != "infinite" ]; then
    if [ ${i} -gt ${CALLS} ]; then 
      break
    fi
  fi
  sleep ${TOTALDELAY}
done
