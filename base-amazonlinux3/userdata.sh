#!/bin/bash

set -uo pipefail

[[ ${V:-} != 1 ]] || set -x

setup_sysfs() {
  local f="/etc/rc.d/rc.local"
  local d="/sys/module/zswap/parameters"
  cat <<-EOF >>"$f"
    echo 'zstd' > $d/compressor
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
  echo -e 'net.ipv4.conf.all.rp_filter=1' >"$dir/93-rp_filter.conf"
  sysctl --system

  umask "$old"
}

install_packages() {
  dnf -y install amazon-ssm-agent amazon-cloudwatch-agent sysstat kpatch-dnf kpatch-runtime
  dnf -y kernel-livepatch auto
  systemctl enable --now amazon-cloudwatch-agent amazon-ssm-agent kpatch

  dnf -y upgrade
  dnf -y clean all

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
