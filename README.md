# A wrapper/warper for TripleO Quickstart

A wrapper container (Fedora-28 based) for
[Quickstart](https://git.openstack.org/cgit/openstack/tripleo-quickstart)
or for running Zuul-based CI reproducers from TripleO CI jobs.

(deprecated use case) It also helps to use the quickstart/extras playbooks
off-road, via direct ansible-playbook commands. And sometimes it works like a
warp jump!

## Requirements for the host OS

* Packer >= 0.12 (omit it, if not going to rebuild the wrapper container)
* Docker >= 1.13 (or podman)
* Libvirt, qemu-kvm, libguestfs (latest perhaps?) with HW access/nested
  virtualization enabled, for local deployments only.

For openstack clouds hosted deployments:
* OpenStack cloud >= Ocata with Heat.
* OpenStack client installed locally.
* OpenStack creds file and pem/pub key files to access the hosting cloud.

> **NOTE** public cloud providers may not allow HW enabled kvm for guest
> VMs. Quickstart will not work on QEMU!

## Build the wrapper container
```
$ packer build packer-docker-fedora28.json
$ packer build packer-docker-oooq-runner.json
```
Adapt these for your case or jut use existing images. It also requires
``OOOQ_PATH`` set and pointing to the quickstart clonned locally.

## Using it with TripleO Zuul-based CI reproducer and libvirt

* [CI reproducer](./docs/CI-reproducer.md)

No longer maintained obsoleted/deprecated contents:

See more:
* [Pre-flight checks for a warp jump](./docs/pre-flight.md)
* [Libvirt virthost preparations](./docs/libvirt-prep.md)
* [Environment configuration basics](./docs/basic-env-prep.md)
* [Quickstart CLI wrapper (quickstart.sh)](./docs/quickstart-cli.md)
* [Direct ansible-playbook commands with custom playbooks](./docs/ansible-direct.md)
* [Troubleshooting local libvirt envs](./docs/troubleshoot.md)

Some WIP deployment examples (which hopefully are still working):
* [Example: local libvirt OVB setup](./docs/ovb-example.md)
* [Example: local libvirt AIO setup with Fedora 28](./docs/f28-example.md)
* [Example: all-in-one undercloud to deploy openshift](./docs/openshift-example.md)
* [Examplle: multinode on openstack pre-provisioned by traas](./docs/traas.md)
