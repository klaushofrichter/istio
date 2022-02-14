#!/bin/bash
set -e

# trying the guess the project home
if [ -z ${PROJECTHOME} ]; then
  if [ -f ./config.sh ]; then 
    export PROJECTHOME=$(pwd)
  else 
    export PROJECTHOME=$(dirname $(pwd))
  fi
fi
source ${PROJECTHOME}/config.sh

[ -z "$1" ] && echo "need one argument to post to slack. Exit." && exit 1
content="{\"text\": \"$1\"}"

curl -X POST -H "Content-type: application/json" --data "${content}" ${SLACKWEBHOOK}
echo
