# AmneziaWG client for router-1 (wg0) -- replaces router.xray. Table = off:
# awg-quick installs no routes, router.singbox's tun is what steers traffic
# onto this interface. Build steps mirror tachiproxy.amneziawg (source
# install, since this distro's repos don't package amneziawg).
#
# The repos are only cloned when something actually needs building, not on
# every apply: router-1's egress to GitHub rides this very tunnel, so a dead
# tunnel must not be able to fail the state that would bring it back up.

amneziawg_build_deps:
  pkg.installed:
    - pkgs:
      - git
      - build-essential
      - make
      - gcc
      - libc6-dev
      - pkg-config
      - dkms
      - libmnl-dev
      - libelf-dev
      - linux-headers-{{ grains['kernelrelease'] }}

amneziawg_tools_repo:
  git.latest:
    - name: https://github.com/amnezia-vpn/amneziawg-tools.git
    - target: /usr/local/src/amneziawg-tools
    - force_reset: True
    - unless: command -v awg && command -v awg-quick
    - require:
      - pkg: amneziawg_build_deps

amneziawg_tools_build:
  cmd.run:
    - name: make && make install
    - cwd: /usr/local/src/amneziawg-tools/src
    - unless: command -v awg && command -v awg-quick
    - require:
      - git: amneziawg_tools_repo

amneziawg_kmod_repo:
  git.latest:
    - name: https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git
    - target: /usr/local/src/amneziawg-linux-kernel-module
    - force_reset: True
    - unless: modinfo amneziawg
    - require:
      - pkg: amneziawg_build_deps

# modinfo, not lsmod: the module only gets loaded once wg0 comes up, so a
# built-but-unloaded module doesn't need rebuilding.
amneziawg_kmod_build:
  cmd.script:
    - source: salt://router/files/install-amneziawg-kmod.sh
    - cwd: /usr/local/src/amneziawg-linux-kernel-module
    - unless: modinfo amneziawg
    - require:
      - git: amneziawg_kmod_repo
      - cmd: amneziawg_tools_build

amneziawg_config_dir:
  file.directory:
    - name: /etc/amnezia/amneziawg
    - mode: '0700'
    - makedirs: True
    - require:
      - cmd: amneziawg_tools_build

wg0_config:
  file.managed:
    - name: /etc/amnezia/amneziawg/wg0.conf
    - source: salt://router/files/wg0.conf.jinja
    - template: jinja
    - mode: '0600'
    - require:
      - file: amneziawg_config_dir

wg0_service:
  service.running:
    - name: awg-quick@wg0
    - enable: True
    - require:
      - file: wg0_config
      - cmd: amneziawg_kmod_build
    - watch:
      - file: wg0_config
