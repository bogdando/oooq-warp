#!/bin/bash -e
dnf -y install python-devel python-virtualenv libvirt-python \
  python-lxml libselinux-python ansible docker-compose \
  python-docker ansible-python3
dnf -y install python3-libvirt python3-lxml python3-virtualenv \
  python3-libselinux python3-netaddr
dnf -y install podman docker osinfo-db-tools virt-install wget \
  gcc which sudo openssl-devel qemu-kvm git libvirt \
  libguestfs-tools polkit-pkla-compat libyaml libffi-devel \
  redhat-rpm-config rsync yum yum-utils NetworkManager
wget https://releases.pagure.org/libosinfo/osinfo-db-20210202.tar.xz
osinfo-db-import -v osinfo-db-20210202.tar.xz
