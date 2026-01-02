#!/bin/bash

TOKEN=$(curl -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" http://169.254.169.254/latest/api/token)
KEY=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/public-keys/" | awk '{print $1}')

if [[ $KEY == "cplane" ]]; then
  ${cplane_join_command}
elif [[ $KEY == "workers" ]]; then
  ${workers_join_command}
fi