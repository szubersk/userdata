#!/bin/bash

set -uo pipefail

[[ ${V:-} != 1 ]] || set -x

setup_sysfs() {
  local f="/etc/rc.d/rc.local"
  local d="/sys/module/zswap/parameters"
  cat <<-EOF >>"$f"
    echo 'lz4' > $d/compressor
    echo 'Y' > $d/enabled
    echo '20' > $d/max_pool_percent
    echo 'zbud' > $d/zpool
EOF
  chmod 0755 "$f"
  "$f"
}

setup_sysctl() {
  local old dir
  dir="/etc/sysctl.d"
  old=$(umask)
  umask 0222

  echo -e 'kernel.pid_max=4194304' >"$dir/90-pid-max.conf"
  echo -e 'fs.protected_fifos=2\nfs.protected_regular=2' >"$dir/91-fs-protected.conf"
  echo -e 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr' >"$dir/92-bbr.conf"
  sysctl --system

  umask "$old"
}

install_packages() {
  yum -y install deltarpm
  amazon-linux-extras enable livepatch python3.8 kernel-5.15
  amazon-linux-extras disable docker kernel-5.10
  yum -y install amazon-ssm-agent amazon-cloudwatch-agent sysstat yum-plugin-kernel-livepatch kpatch-runtime
  yum kernel-livepatch enable -y
  systemctl enable --now amazon-cloudwatch-agent amazon-ssm-agent kpatch

  yum -y upgrade
  yum clean all

  amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c ssm:AmazonCloudWatch-amazonlinux -s
}

setup_swap() {
  local swap="/swap"
  dd if=/dev/zero of="$swap" bs=1M count=2048
  chmod 0600 "$swap"
  mkswap "$swap"
  swapon "$swap"
  echo "$swap swap swap defaults" >>/etc/fstab
}

main() {
  echo "$0 starting"

  local pids=()
  setup_swap &
  pids+=($!)
  install_packages &
  pids+=($!)
  setup_sysctl &
  pids+=($!)
  setup_sysfs &
  pids+=($!)

  for p in "${pids[@]}"; do wait "$p"; done

  echo "$0 finished"
}

main "$@"
