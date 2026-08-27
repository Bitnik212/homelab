#!/usr/bin/env bash
# Builds/installs the amneziawg DKMS kernel module. Adapted from
# install-amneziawg.sh's install_kernel_module()/detect_dkms_version() —
# run after amneziawg_kmod_repo (git.latest) has cloned the kernel module
# source. Idempotency is handled by the calling state's `unless`.
set -Eeuo pipefail

KMOD_NAME="amneziawg"
KERNEL_VERSION="$(uname -r)"
KMOD_DIR="/usr/local/src/amneziawg-linux-kernel-module"

detect_dkms_version() {
  local conf_file=""
  if [[ -f "${KMOD_DIR}/src/dkms.conf" ]]; then
    conf_file="${KMOD_DIR}/src/dkms.conf"
  elif [[ -f "${KMOD_DIR}/dkms.conf" ]]; then
    conf_file="${KMOD_DIR}/dkms.conf"
  else
    echo "dkms.conf not found in kernel module repo" >&2
    exit 1
  fi
  grep -E '^PACKAGE_VERSION=' "${conf_file}" | head -n1 | cut -d= -f2 | tr -d '"'
}

dkms_version="$(detect_dkms_version)"
dkms_src_dir="/usr/src/${KMOD_NAME}-${dkms_version}"

rm -rf "${dkms_src_dir}"
dkms remove -m "${KMOD_NAME}" -v "${dkms_version}" --all >/dev/null 2>&1 || true

mkdir -p "${dkms_src_dir}"
cp -a "${KMOD_DIR}/src/." "${dkms_src_dir}/"

dkms add -m "${KMOD_NAME}" -v "${dkms_version}"
dkms build -m "${KMOD_NAME}" -v "${dkms_version}" -k "${KERNEL_VERSION}"
dkms install -m "${KMOD_NAME}" -v "${dkms_version}" -k "${KERNEL_VERSION}"

depmod -a
modprobe "${KMOD_NAME}"
