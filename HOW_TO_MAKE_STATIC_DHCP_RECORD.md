# How to make a static DHCP record

Applies to VMs on the main LAN (vmbr0, `10.20.10.0/24`) — router-1 and the
hashibr bridge (`10.30.30.0/24`) are a **different** DHCP server (isc-dhcp-server
on the router-1 VM, config templated by Salt) and aren't covered by this doc;
see `salt/router/dhcp.sls` and `pillar/router.sls`'s `hashibr` section for that
one instead.

The main LAN's gateway is an OpenWrt box at `10.20.10.1` running dnsmasq. It
already has a helper script, `fix-dhcp-record.sh`, installed at its root home
dir — this doc is just how to drive it.

## Prerequisite

The VM must already have picked up a **live** DHCP lease — the script reads
the current lease table (`/tmp/dhcp.leases`) and matches on the hostname the
client sent, so if the VM hasn't booted yet, or its lease expired, there's
nothing to convert.

- Every VM here gets its hostname from cloud-init (`name = "..."` in the
  `proxmox_virtual_environment_vm` resource, e.g. `vm-elk`), so the DHCP
  hostname matches the Terraform/Proxmox name.
- Check the VM currently has a lease:
  ```
  ssh root@10.20.10.1 grep <hostname> /tmp/dhcp.leases
  ```
  If nothing comes back, wait for the VM to finish booting (or force a
  renewal inside it — see "Renewing after the change" below) and try again.

## Making the record

```
ssh root@10.20.10.1 ./fix-dhcp-record.sh <hostname>
```

e.g. `ssh root@10.20.10.1 ./fix-dhcp-record.sh vm-elk`

This pins the VM to **whatever IP it currently has** — it reads the live
lease's MAC + IP, then finds or creates a UCI `dhcp.host` section for that MAC
and sets `name`/`mac`/`ip` on it, commits, and reloads dnsmasq. It does not
let you hand it an arbitrary IP; if the VM's current lease isn't the address
you want, either let it lease again (dynamic pool is whatever's unused) until
it lands somewhere acceptable, or `ssh root@10.20.10.1` and `uci set
dhcp.<section>.ip=<desired-ip>` by hand afterwards, then `uci commit dhcp &&
/etc/init.d/dnsmasq reload`.

Add `--dns` to also register forward/reverse DNS for the hostname in dnsmasq:

```
ssh root@10.20.10.1 ./fix-dhcp-record.sh vm-elk --dns
```

## Verifying

```
ssh root@10.20.10.1 uci show dhcp
```

Look for a `dhcp.@host[N].name='<hostname>'` entry with the expected `mac`
and `ip`.

## Renewing after the change

The VM keeps its current lease until it renews, so the reservation doesn't
take visible effect until then. To force it immediately, on the VM:

```
sudo systemctl restart systemd-networkd   # netplan/systemd-networkd (default here)
# or: sudo dhclient -r ens18 && sudo dhclient ens18
```

A reboot works too, but isn't necessary — the reservation only matters on
the *next* DHCP request, which a renewal alone triggers.
