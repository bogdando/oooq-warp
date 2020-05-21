#!/bin/bash -e
dnf -y install gcc python-devel openssl-devel python-virtualenv \
  libvirt wget which sudo qemu-kvm libvirt-python \
  libguestfs-tools python-lxml polkit-pkla-compat git
dnf -y install libyaml libselinux-python libffi-devel \
  openssl-devel redhat-rpm-config rsync yum
dnf -y install docker docker-compose python-docker ansible-python3 \
  python3-libvirt python3-lxml python3-virtualenv
