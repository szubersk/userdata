#!/bin/bash

set -uo pipefail

[[ ${V:-} != 1 ]] || set -x

main() {
  echo "$0 starting"

  yum -y upgrade
  yum -y install amazon-ssm-agent amazon-cloudwatch-agent
  yum clean all

  systemctl enable --now amazon-cloudwatch-agent amazon-ssm-agent
  amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c ssm:AmazonCloudWatch-amazonlinux -s

  echo "$0 finished"
}

main "$@"
