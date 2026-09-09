# Full-tunnel AmneziaWG client for vm-tachiproxy -- the ISP is blocking
# outbound HTTP proxy connections outright, so all of this VM's egress
# needs to go through the tunnel instead, not just select destinations
# (contrast salt/elk/hashibr_route.sls's per-IP approach, or
# router.amneziawg's split-tunnel). Same server as router-1's own tunnel
# (salt/router/amneziawg.sls), just a second peer/client on it.
#
# Build steps mirror router.amneziawg (source install, since this distro's
# repos don't package amneziawg) -- reuses its kmod-build script since
# that part is generic, but everything else is separate because it's
# templated from a different pillar key (tachiproxy.amneziawg, not
# router.amneziawg) and targets a different minion.

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
    - require:
      - pkg: amneziawg_build_deps

amneziawg_kmod_build:
  cmd.script:
    - source: salt://router/files/install-amneziawg-kmod.sh
    - cwd: /usr/local/src/amneziawg-linux-kernel-module
    - unless: lsmod | grep -q '^amneziawg'
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
    - source: salt://tachiproxy/files/wg0.conf.jinja
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
