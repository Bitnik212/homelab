#!/usr/bin/env bash
# Installs the AmneziaWG client on a Debian/Ubuntu box: builds awg-tools and
# the DKMS kernel module from source (same repos/steps as
# salt/router/files/splittunnel/install-amneziawg.sh), then installs a given
# client config and brings the interface up via awg-quick@<name>.
#
# Usage: sudo bash install-awg-client.sh /path/to/client.conf [interface-name]
set -Eeuo pipefail

TOOLS_REPO="https://github.com/amnezia-vpn/amneziawg-tools.git"
KMOD_REPO="https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git"

TOOLS_DIR="/usr/local/src/amneziawg-tools"
KMOD_DIR="/usr/local/src/amneziawg-linux-kernel-module"
CONF_DIR="/etc/amnezia/amneziawg"

KMOD_NAME="amneziawg"
KERNEL_VERSION="$(uname -r)"

CONFIG_SRC="${1:-}"
IFACE="${2:-awg0}"

log() { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*" >&2; }
err() { echo -e "[ERROR] $*" >&2; }

usage() {
  echo "Usage: sudo bash $0 /path/to/client.conf [interface-name]" >&2
  echo "  client.conf   AmneziaWG/WireGuard client config (from the server/wg-easy)" >&2
  echo "  interface-name  defaults to 'awg0'" >&2
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Run this script as root: sudo bash $0"
    exit 1
  fi
}

cleanup_on_error() {
  local exit_code=$?
  err "Installer failed with exit code ${exit_code}"
  err "Last known kernel: ${KERNEL_VERSION}"

  if command -v dkms >/dev/null 2>&1; then
    warn "DKMS status:"
    dkms status || true
  fi

  local dkms_log=""
  dkms_log="$(find "/var/lib/dkms/${KMOD_NAME}" -type f -name make.log 2>/dev/null | head -n 1 || true)"
  if [[ -n "${dkms_log}" && -f "${dkms_log}" ]]; then
    warn "Showing DKMS build log: ${dkms_log}"
    tail -n 100 "${dkms_log}" || true
  fi
}

trap cleanup_on_error ERR

install_packages() {
  log "Installing required packages"
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y \
    git \
    build-essential \
    make \
    gcc \
    libc6-dev \
    pkg-config \
    dkms \
    libmnl-dev \
    libelf-dev \
    linux-headers-"${KERNEL_VERSION}"

  # Lets awg-quick manage resolv.conf when the config sets DNS=; not fatal if
  # unavailable (e.g. systemd-resolved-only systems).
  DEBIAN_FRONTEND=noninteractive apt install -y openresolv || \
    warn "Could not install openresolv; DNS= in the config may not apply"
}

clone_or_update_repo() {
  local repo_url="$1"
  local target_dir="$2"

  if [[ -d "${target_dir}/.git" ]]; then
    log "Updating repo ${target_dir}"
    git -C "${target_dir}" fetch --all --tags
    git -C "${target_dir}" reset --hard origin/master || \
    git -C "${target_dir}" reset --hard origin/main
  else
    log "Cloning ${repo_url} into ${target_dir}"
    rm -rf "${target_dir}"
    git clone "${repo_url}" "${target_dir}"
  fi
}

install_tools() {
  log "Installing amneziawg-tools"
  clone_or_update_repo "${TOOLS_REPO}" "${TOOLS_DIR}"

  cd "${TOOLS_DIR}/src"
  make
  make install

  log "Checking installed binaries"
  command -v awg >/dev/null 2>&1 || { err "awg binary not found"; exit 1; }
  command -v awg-quick >/dev/null 2>&1 || { err "awg-quick binary not found"; exit 1; }

  awg --version || true
}

detect_dkms_version() {
  local conf_file=""
  local version=""

  if [[ -f "${KMOD_DIR}/src/dkms.conf" ]]; then
    conf_file="${KMOD_DIR}/src/dkms.conf"
  elif [[ -f "${KMOD_DIR}/dkms.conf" ]]; then
    conf_file="${KMOD_DIR}/dkms.conf"
  else
    err "dkms.conf not found in kernel module repo"
    exit 1
  fi

  version="$(grep -E '^PACKAGE_VERSION=' "${conf_file}" | head -n1 | cut -d= -f2 | tr -d '"')"

  if [[ -z "${version}" ]]; then
    err "Could not detect PACKAGE_VERSION from ${conf_file}"
    exit 1
  fi

  echo "${version}"
}

install_kernel_module() {
  log "Installing amneziawg kernel module"
  clone_or_update_repo "${KMOD_REPO}" "${KMOD_DIR}"

  cd "${KMOD_DIR}/src"

  local dkms_version
  dkms_version="$(detect_dkms_version)"
  local dkms_src_dir="/usr/src/${KMOD_NAME}-${dkms_version}"

  log "Detected DKMS version: ${dkms_version}"

  rm -rf "${dkms_src_dir}"
  dkms remove -m "${KMOD_NAME}" -v "${dkms_version}" --all >/dev/null 2>&1 || true

  mkdir -p "${dkms_src_dir}"
  cp -a . "${dkms_src_dir}/tmp-copy"
  cp -a "${dkms_src_dir}/tmp-copy"/. "${dkms_src_dir}/"
  rm -rf "${dkms_src_dir}/tmp-copy"

  dkms add -m "${KMOD_NAME}" -v "${dkms_version}"
  dkms build -m "${KMOD_NAME}" -v "${dkms_version}" -k "${KERNEL_VERSION}"
  dkms install -m "${KMOD_NAME}" -v "${dkms_version}" -k "${KERNEL_VERSION}"

  depmod -a
  modprobe "${KMOD_NAME}"
}

install_client_config() {
  if [[ -z "${CONFIG_SRC}" ]]; then
    warn "No config file given, skipping client config install and service enable"
    warn "Re-run as: sudo bash $0 /path/to/client.conf [interface-name]"
    return
  fi

  if [[ ! -f "${CONFIG_SRC}" ]]; then
    err "Config file not found: ${CONFIG_SRC}"
    exit 1
  fi

  log "Installing client config as ${IFACE}"
  mkdir -p "${CONF_DIR}"
  install -m 600 -o root -g root "${CONFIG_SRC}" "${CONF_DIR}/${IFACE}.conf"
}

enable_service() {
  if [[ -z "${CONFIG_SRC}" ]]; then
    return
  fi

  log "Enabling awg-quick@${IFACE}"
  systemctl enable --now "awg-quick@${IFACE}"
}

verify_install() {
  log "Verifying installation"

  command -v awg >/dev/null 2>&1 || { err "awg is not installed"; exit 1; }
  command -v awg-quick >/dev/null 2>&1 || { err "awg-quick is not installed"; exit 1; }

  if ! lsmod | grep -q "^${KMOD_NAME}\b"; then
    err "Kernel module ${KMOD_NAME} is not loaded"
    exit 1
  fi

  local module_path
  module_path="$(find "/lib/modules/${KERNEL_VERSION}" -type f | grep "/${KMOD_NAME}\." | head -n1 || true)"

  if [[ -z "${module_path}" ]]; then
    err "Installed module file not found under /lib/modules/${KERNEL_VERSION}"
    exit 1
  fi

  log "Success"
  echo "awg binary:       $(command -v awg)"
  echo "awg-quick binary: $(command -v awg-quick)"
  echo "module path:      ${module_path}"
  dkms status || true

  if [[ -n "${CONFIG_SRC}" ]]; then
    systemctl status "awg-quick@${IFACE}" --no-pager || true
  fi
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  require_root
  install_packages
  install_tools
  install_kernel_module
  install_client_config
  enable_service
  verify_install
}

main "$@"
