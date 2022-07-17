#!/bin/bash

set -uo pipefail

[[ ${V:-} != 1 ]] || set -x

main() {
  yum -y install squid

  AWS_DEFAULT_REGION=ap-southeast-2 aws ssm get-parameter --name '/service/httpproxy/squid.conf' --query 'Parameter.Value' --output text >/etc/squid/squid.conf
  AWS_DEFAULT_REGION=ap-southeast-2 aws ssm get-parameter --name '/service/httpproxy/passwords' --query 'Parameter.Value' --output text >/etc/squid/passwords
  chown root:squid /etc/squid/passwords

  systemctl enable squid
  systemctl restart squid
}

main "$@"
