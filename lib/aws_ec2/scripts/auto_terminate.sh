#!/bin/bash -exu

if [ $# -eq 0 ]; then
  command=$(basename "$0")
  echo "Usage: $command WHEN"
  echo "Examples:"
  echo "  $command now"
  echo "  $command later"
  exit 1
fi
WHEN=$1 # now or later

source /opt/aws-ec2/auto_terminate/functions.sh
terminate "$WHEN"
