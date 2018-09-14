# Troubleshooting local libvirt envs

> **NOTE** there is ``_deploy.log`` and ``_deploy_nice.log`` produced for
> inspection if the deployment results. It is also persisted by the given
> ``OOOQ_PATH``.

If the undercloud VM refuses to start (permission deinied) on Ubuntu, try
to disable apparmor for libvirt and reconfigure qemu as well:
```
# echo "dynamic_ownership = 0" >> /etc/libvirt/qemu.conf
# echo 'group = "root"' >> /etc/libvirt/qemu.conf
# echo 'user = "root"' >> /etc/libvirt/qemu.conf
# echo 'security_driver = "none"' >> /etc/libvirt/qemu.conf
# sudo systemctl restart libvirt-bin || sudo systemctl restart libvirtd
# sudo systemctl restart qemu-kvm
```

If ``libguestfs-test-tool`` fails, try to adjust ``SUPERMIN_KERNEL``,
``SUPERMIN_KERNEL_VERSION``, ``SUPERMIN_MODULES`` and ``LIBGUESTFS_BACKEND``.
Or only unset ``LIBGUESTFS_BACKEND_SETTINGS``, then quickstart picks up
safe (and very slow) defaults.

More sysctl adjustments may be required to fix inter-VMs connectivity:
```
# sysctl net.bridge.bridge-nf-call-ip6tables=0
# sysctl net.bridge.bridge-nf-call-iptables=0
# sysctl net.bridge.bridge-nf-call-arptables=0
# sysctl net.ipv4.ip_forward=1
```
And some more optional magic for PXE boot issue on libvirt
```
# sysctl net.ipv4.conf.default.proxy_arp=1
# sysctl net.ipv4.conf.brovc.proxy_arp=1
# brctl stp brovc off #default on
# brctl setfd brovc 0.1 #default 15
# iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
```
