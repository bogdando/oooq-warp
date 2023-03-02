# A wrapper/warper for TripleO Quickstart

A wrapper container (Centos 9 Stream based) for
[Quickstart](https://git.openstack.org/cgit/openstack/tripleo-quickstart)
for running Zuul-based CI reproducers from TripleO CI jobs.

## Requirements for the host OS

* Packer (omit it, if not going to rebuild the wrapper container)
* Docker (or podman)
* Libvirt, qemu-kvm, libguestfs, with HW access/nested
  virtualization enabled, for local deployments only.

## Build the wrapper container
```
$ packer build packer-docker-fedora28.json
$ packer build packer-docker-oooq-runner.json
```
Adapt these for your case or jut use existing images. It also requires
``OOOQ_PATH`` set and pointing to the quickstart clonned locally.

## Using it with TripleO Zuul-based CI reproducer and libvirt

* [CI reproducer](./docs/CI-reproducer.md)
* [Troubleshooting local libvirt envs](./docs/troubleshoot.md)
