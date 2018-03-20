# A wrapper/warper for TripleO Quickstart

A wrapper centos7 container that makes
[Quickstart](https://git.openstack.org/cgit/openstack/tripleo-quickstart)
thinking it's running at centos box.

Some of the included example playbooks omit build/provision steps
executed by default, when operated via ``quickstart.sh``.

It also helps to use the quickstart/extras playbooks off-road, via direct
ansible-playbook commands. And sometimes it works like a warp jump!

It may as well be used to deploy with [traas](https://github.com/slagle/traas)
on openstack clouds and
[pre-provisioned/deployed servers](https://docs.openstack.org/tripleo-docs/latest/install/advanced_deployment/deployed_server.html).

## Requirements for the host OS

* Packer >= 0.12 (omit it, if not going to rebuild the wrapper container)
* Docker >= 1.13
* Libvirt, qemu-kvm, libguestfs (latest perhaps?) with HW access/nested
  virtualization enabled, for local deployments only.

For non local (traas) deployments:
* OpenStack cloud >= Ocata with Heat.
* OpenStack client installed locally.
* OpenStack creds file and pem/pub key files to access the hosting cloud.

> **NOTE** public cloud providers may not allow HW enabled kvm for guest
> VMs. Quickstart will not work on QEMU!

## Build the wrapper container
```
$ packer build packer-docker-centos7.json
$ packer build packer-docker-oooq-runner.json
```
Note, adapt those for your case or jut use existing images. It also requires
``OOOQ_PATH`` set and pointing to the quickstart clonned locally.

## Pre-flight checks for a warp jump

To start a scratch local dev env with libvirt and kvm:

* Download the overcloud-full, undercloud and ironic-python-agent images and md5
  files into ``IMAGECACHE``.

  > **NOTE**: Backup those for future re-provision runs in ``${IMAGECACHEBACKUP}``!
  > Quickstart mutates qcow2 files in-place. You may want to preserve the
  > original images for future deployments.

  For libvirt dev envs, pick any of these sources:
  * [The most recent, the less stable](https://images.rdoproject.org/master/delorean/current-tripleo/),
    for hardcore devs
  * [(Non HTTPS link!) more stable and older images](http://artifacts.ci.centos.org/rdo/images/master/delorean/consistent/),
    it is also the default OOOQ choice ([HTTPS mirror](https://images.rdoproject.org/master/delorean/consistent/)).
  * [The one](https://buildlogs.centos.org/centos/7/cloud/x86_64/tripleo_images/master/delorean/) from the
    [Docs](https://tripleo.org/basic_deployment/basic_deployment_cli.html).

* Customize and export some env vars, for example:
  ```
  $ export USER=bogdando # used as undercloud/overcloud SSH user as well
  $ export DLRN_HASH=current-tripleo
  $ export WORKSPACE=/tmp/qs       #persisted on host, libvirt revers to it
  $ export IMAGECACHE=/opt/cache   #persistent on host
  $ export LWD=${HOME}/.quickstart #persistent on host, may be equal to WORKSPACE
  $ export OOOQE_BRANCH=dev
  $ export OOOQE_FORK=johndoe
  $ export OOOQ_BRANCH=dev
  $ export OOOQ_FORK=johbdoe
  ```
  Or use ``OOOQE_PATH`` and/or ``OOOQ_PATH``, if you already have then clonned
  somewhere locally.

* Export a custom ``PLAY`` and/or ``CUSTOMVARS``. The default play is
  is ``oooq-libvirt-provision-build.yaml`` (see the `playbooks` dir) and the default
  overrides file is invoked as `-e@custom.yaml`:

* If picked ``PLAY=oooq-libvirt-provision.yaml``, which may be the case for
  undercloud-only deployments (w/o overclouds expected on top), extract kernel images
  with the command executed from the host machine:
  ```
  # virt-copy-out -a ${IMAGECACHE}/undercloud.qcow2 \
    /home/stack/overcloud-full.vmlinuz \
    /home/stack/overcloud-full.initrd ${WORKSPACE}
  ```

  > **NOTE** this might leave you with an oudated kernel, fall back to the
  > default ``PLAY`` option then!

* Prepare host for nested kvm and do some sysctl magic:
  ```
  # echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
  # modprobe -r kvm_intel
  # modprobe kvm_intel
  # cat /sys/module/kvm_intel/parameters/nested
  ```

* Copy example data vars ``custom.yaml_example`` as ``custom.yaml`` and check for
  needed data overrides. Note, it contains only common vars for all plays. Use var files
  from the ``vars`` dir (or quickstart's releases configs) for advanced configuration
  overrides. Additional overriding is also possible with ``CUSTOMVARS=something.yaml``
  and ``-e/-e@`` args.

  > **NOTE** ``custom.yaml``/``CUSTOMVARS`` applies with each ``create_env_oooq.sh``
  command with the **top level** vars precedence. Do not put there any vars you want
  to override elsewhere, like from the vars files shipped with plays or quickstart's
  releases config files! You can also override ``custom.yaml``/``CUSTOMVARS`` from
  extra files or parameters passed with ``create_env_oooq.sh -e foo=bar -e@baz.yml``.

* Execute the wanted ``PLAY`` with the command like:
```
(oooq) PLAY=something.yaml create_env_oooq.sh -e foo=bar -e@baz.yml -vvvv
```

> **NOTE** You can access the undercloud VMs with the command:
> ```
> $ ssh -F ${LWD}/ssh.config.local.ansible undercloud
> ```

### Example playbooks for a local libvirt env ready for OVB setup

The expected workflow is:

* provision a libvirt env, it creates a running undercloud VM and shut-off VMs
  from the ``overcloud_nodes`` passed.
* Install undercloud as a separate step (optional, depends on the next step)
* Deploy a particular quickstart's CI featureset, given a nodes-file and/or a
  config release file, added your custom ansible CLI args and ``CUSTOMVARS``.
* Proceed with OVB, f.e. executred from the provided ``reproduce-quickstart.sh``.

Example commands (``(oooq)`` represents the shell prompt in the wrapper container):

* Provision the long path with building images et al
```
(oooq) ./quickstart.sh --install-deps
(oooq) PLAY=oooq-libvirt-provision-build.yaml create_env_oooq.sh \
           -e@config/nodes/1ctlr_1comp.yml \
           -e@config/release/master.yml \
           -e@/tmp/scripts/custom.yaml \
           -e@/tmp/scripts/tht/config/general_config/featureset062.yml
```

> **NOTE** The ``dlrn_hash_tag`` value is configured from ``DLRN_HASH`` and
> must be matching the version in the source URL of the downloaded images. Do
> not attempt to override ``dlrn_hash`` top-scope as it breaks the fact
> auto-eval in quickstart repo-setup!

* Install undercloud (keeping in mind fs062 for overcloud has top precedence)
```
(oooq) export HOST_BREXT_IP=192.168.23.1
(oooq) ./quickstart.sh -R master -n -I -T none -t all \
           -N config/nodes/1ctlr_1comp.yml \
           -E /tmp/scripts/vars/undercloud-local.yaml \
           -E /tmp/scripts/custom.yaml \
           -E /tmp/scripts/tht/config/general_config/featureset062.yml \
           -p quickstart-extras-undercloud.yml \
           -e transport=local \
           -e vbmc_libvirt_uri="qemu+ssh://${USER}@${HOST_BREXT_IP}/session?socket=/run/libvirt/libvirt-sock&keyfile=/root/.ssh/id_rsa_virt_power&no_verify=1&no_tty=1" \
           localhost
```
> **FIXME**: the socket path is hardcoded in quickstart for RHEL OS family,
> so we have to override the ``vbmc_libvirt_uri`` and manually evaluate ``HOST_BREXT_IP``.
> To verify the connection, run from the undercloud node deployed (substitute with real values):
> ```
> $ sudo virsh connect "qemu+ssh://${USER}@${HOST_BREXT_IP}/session?socket=/run/libvirt/libvirt-sock&keyfile=/root/.ssh/id_rsa_virt_power&no_verify=1&no_tty=1"
> ```

* On undercloud VM, configure ``USER`` to
  access the docker CLI w/o sudo (substitute with the real value):
```
$ sudo usermod -aG root $USER
$ sudo usermod -aG dockerroot $USER
```

* Deploy overcloud from the given featureset and nodes config
```
(oooq) ./quickstart.sh -R master -n -I -T none -t all \
           -S tripleo-validations \
           -p quickstart-extras-overcloud-prep.yml \
           -N config/nodes/1ctlr_1comp.yml \
           -E /tmp/scripts/vars/undercloud-local.yaml \
           -E /tmp/scripts/custom.yaml \
           -E /tmp/scripts/tht/config/general_config/featureset062.yml \
           -e transport=local localhost

(oooq) ./quickstart.sh -R master -n -I -T none -t all \
           -S tripleo-validations \
           -p quickstart-extras-overcloud.yml \
           -N config/nodes/1ctlr_1comp.yml \
           -E /tmp/scripts/vars/undercloud-local.yaml \
           -E /tmp/scripts/custom.yaml \
           -E /tmp/scripts/tht/config/general_config/featureset062.yml \
           -e transport=local localhost
```
* Deploy your OVB setup on top

### Respinning a failed local libvirt env

If you want to reuse the existing (already customized by oooq) images and omit
all of the long playing build/provisioning steps:
* Export ``TEARDOWN=false`` then rerun the deploy inside of the
  container or start a new container.

To start a new libvirt env from the scratch:

* remove existing VMs' snapshots,
* exit the wrapper container,
* start a new container with ``TEARDOWN=true ./oooq-warp.sh``, or the like.

> **NOTE** When rebuilding from the scratch, you can still configure quickstart
> to re-use the kernel/latest fetched overcloud/ironic-python-agent images from
> the ``IMAGECACHEBACKUP`` dir, for example:
> ```
> (oooq) PLAY=oooq-libvirt-provision-build.yaml create_env_oooq.sh \
>            -e@config/nodes/1ctlr_1comp.yml \
>            -e@config/release/master.yml \
>            -e@/tmp/scripts/custom.yaml \
>            -e@/tmp/scripts/tht/config/general_config/featureset062.yml \
>            -e undercloud_use_custom_boot_images=true \
>            -e undercloud_custom_initrd=${IMAGECACHE}/overcloud-full.initrd \
>            -e undercloud_custom_vmlinuz=${IMAGECACHE}/overcloud-full.vmlinuz \
>            -e force_cached_images=true -e image_cache_expire_days=30
> ```
> **TODO**: needs https://review.openstack.org/#/c/554627 !

If you want to include steps like re-fetching remote images and re-building
the kernel images et al, just remove the corresponding images from the
backup dir.

### Troubleshooting local libvirt envs

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

More sysctl adjustments may be required to fix inter-VMs connectivity:
```
# sysctl net.bridge.bridge-nf-call-ip6tables=0
# sysctl net.bridge.bridge-nf-call-iptables=0
# sysctl net.bridge.bridge-nf-call-arptables=0
# sysctl net.ipv4.ip_forward=1
```

## Non-local (traas) multinode pre-provisioned deployment on openstack

Follow an [all-in-one undercloud example guide](rdocloud-guide.md)
(RDO cloud), or read below for advanced deployment scenarios.

> **NOTE** the private key from the generated Nova keypair should be
> copied under the ``$LWD`` path.

Update the ``vars/inventory-traas.yaml`` vars file with required info, like
OpenStack cloud access secrets and endpoints. Now you need to generate an
ansible inventory for the undercloud/overcloud VMs on OpenStack (see
also [Traas](https://github.com/bogdando/traas)):
```
$ export PLAY=oooq-traas.yaml
```
Make sure there are no artificial/obsolete node entries remaining at the
``$LWD/hosts`` (or just remove the file) and run:
```
$ ./oooq-warp.sh
(oooq) create_env_oooq.sh
```
Note, it places the given openstack cloud provider access secrets under the
``$LWD/clouds.yaml`` or ``$LWD/stackrc``. The ``$LWD`` dir is bind-mounted
into the wrapper container and is persisted across different containers runs.

Then deploy with custom tripleo-extras roles, like:
```
(oooq) export PLAY=oooq-traas-under.yaml
(oooq) create_env_oooq.sh
(oooq) export PLAY=oooq-traas-over.yaml
(oooq) export CONTROLLER_HOSTS="<private_v4_1> ... <private_v4_N>"
(oooq) export SUBNODES_SSH_KEY=/home/centos/.ssh/id_rsa
(oooq) create_env_oooq.sh
```
Note, the deployed-server configuration task requires a few env vars to be
exported to contain the pre-provisioned environment specific values (see
[deployed-server](https://docs.openstack.org/developer/tripleo-docs/advanced_deployment/deployed_server.html)
docs for details), like (Traas specific provisioning scripts) ssh key path,
deployed servers' IPs.
Use the ``openstack --os-cloud my-cool-cloud server list`` outputs to get
a list of controllers/computes/etc private IPs for export.
SSH keys placement is up to cloud init scripts for the pre-provisioned hosts.
Traas creates them under the centos user home by default.
