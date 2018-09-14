# Libvirt virthost preparations

Prepare host for nested kvm and do some sysctl magic:
```
# echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
# modprobe -r kvm_intel
# modprobe kvm_intel
# cat /sys/module/kvm_intel/parameters/nested
# export LIBGUESTFS_BACKEND_SETTINGS=network_bridge=virbr0
# export HOST_BREXT_IP=192.168.23.1 # should be real IP of virbr0
 ```
As we mount ``/boot`` into container for libguestfs tools, the kernel image
needs to be world read, so run:
```
# chmod a+r /boot/vmlinuz*
```
