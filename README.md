# A wrapper/warper for TripleO Quickstart

A wrapper centos7 container that makes
[Quickstart](https://git.openstack.org/cgit/openstack/tripleo-quickstart)
thinking it's running at centos box.

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

For openstack clouds hosted deployments:
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
Adapt these for your case or jut use existing images. It also requires
``OOOQ_PATH`` set and pointing to the quickstart clonned locally.

## Pre-flight checks for a warp jump

To start a scratch local dev env with libvirt and kvm:

Download the overcloud-full, undercloud and ironic-python-agent images and md5
files into ``IMAGECACHE``. Or omit that step if you want quickstart do that
for you based on the given ``dlrn_hash_tag``.

> **NOTE**: Backup those for future re-provision runs in ``${IMAGECACHEBACKUP}``!
> You may want to preserve the original images for future deployments.

Pick any of these sources:

* [The most recent, the less stable](https://images.rdoproject.org/master/delorean/current-tripleo/),
  for hardcore devs
* [(Non HTTPS link!) more stable and older images](http://artifacts.ci.centos.org/rdo/images/master/delorean/consistent/),
  it is also the default OOOQ choice ([HTTPS mirror](https://images.rdoproject.org/master/delorean/consistent/)).
* [The one](https://buildlogs.centos.org/centos/7/cloud/x86_64/tripleo_images/master/delorean/) from the
  [Docs](https://tripleo.org/basic_deployment/basic_deployment_cli.html).

When using ``overcloud_as_undercloud``, you may omit downloading the
`undercloud.qcow2` image.

## Libvirt virthost preparations

* Prepare host for nested kvm and do some sysctl magic:
  ```
  # echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
  # modprobe -r kvm_intel
  # modprobe kvm_intel
  # cat /sys/module/kvm_intel/parameters/nested
  # export LIBGUESTFS_BACKEND_SETTINGS=network_bridge=virbr0
  # export HOST_BREXT_IP=192.168.23.1 # should be real IP of virbr0
  ```

## Environment configuration basics

* Customize and export some additional env-specific vars, for example:

  ```
  $ export TEARDOWN=true # start a scratch environment, rebuild images, regen ssh keys.
  $ export USER=bogdando # undercloud/overcloud/SSH-admin/local virthost user
  $ export WORKSPACE=/tmp # must exist on the virthost and UC VM, libvirt revers to it
  $ export IMAGECACHE=/opt/cache # should exist on the virthost for persistent deployments
  $ export LWD=${HOME}/.quickstart # should exist on the virthost, may be equal to WORKSPACE
  $ export OOOQE_BRANCH=dev
  $ export OOOQE_FORK=johndoe
  $ export OOOQ_BRANCH=dev
  $ export OOOQ_FORK=johbdoe
  ```
  Or use ``OOOQE_PATH`` and/or ``OOOQ_PATH``, if you already have then clonned
  somewhere locally.

> **NOTE** If you chose ``RAMFS=true`` or non existing virthost paths, some/all
> of the WORKSPACE/IMAGECACHE/LWD paths may be ignored and become ephemeral
> (like the container run time only) ``/home/$USER`` and/or bind-mounted via
> ``/tmp`` host-path.  This speeds up provisioning steps, but eats a lot of RAM.
> Also note, using the current user home is not allowed for these paths,
> assuming the virthost is not a disbosable/throw-away host and logged in user
> should be affected by potentially destructive teardown actions.

* Start an interactive wrapper-container session:
  ```
  $ ./oooq-warp.sh
  ```
  See also non-interactive mode explained below.

At this point, the content of ``IMAGECACHEBACKUP`` will be recovered by
the ``IMAGECACHE`` path, and `latest-` sylinks will be auto-regenereted for
future quickstart provisioning playbooks use.

If you requested teardown and **really** want to nuke everything and fetch the
new images, run ``save-state.sh --purge``.

## Quickstart CLI wrapper (quickstart.sh)

Use the ``quickstart.sh`` wrapper as usual but in the wrapper container. For example,
using localhost as virthost and privileged libvirt mode:
```
(oooq) quickstart.sh -R master -e dlrn_hash_tag=current-tripleo --no-clone \
         -N config/nodes/1ctlr_1comp.yml \
         -E config/environments/dev_privileged_libvirt.yml \
         -E /var/tmp/scripts/vars/quickstart.yaml \
         -t all -T all localhost
```
Save the produced state with the ``save-state.sh --sync`` wrapper.

> **NOTE** It is an important step to keep the disconnected working dirs and image caches
> content in sync.

## Reprovisioning quickly (warp! warp! warp!)

To reprovision with the cached images, add the original command:
```
-E /var/tmp/scripts/vars/quickstart-cached-images.yaml -T none
```

> **FIXME**  It always stops the halfway of provisioning currently, as you manually
> need to update the virthost authorized keys with the generated SSH keys. So
> you'll need to continue it like in the given example command above.

Running with ``--clean`` will recreate the venv. But it makes more sense just
to rebuild the container and never use the ``--clean`` parameter run-time.

If you only want to re-install/update in-place UC and skip anything that
predates that even faster then doing idempotent ansible apply, add
```
--skip-tags teardown-all,provision,environment,libvirt,undercloud-inventory \
  -T none -I
```
The same, but going stright to overcloud deployment:
```
--skip-tags provision,environment,libvirt,undercloud-setup,undercloud-install,undercloud-post-install,tripleo-validations \
  -e docker_registry_namespace_used=tripleo-master -T none -I -t all
```
``docker_registry_namespace_used`` Needs to be defined as we skip the
``undercloud-install`` tag.

## Direct ansible-playbook commands with custom playbooks

Alternatively, you can go with ``create_env_oooq.sh`` wrapper around direct
ansible-playbook commands and custom playbooks:

* Export a custom ``PLAY`` and/or ``CUSTOMVARS``. The default play is
  is ``oooq-libvirt-provision-build.yaml`` (see the `playbooks` dir) and the default
  overrides file is invoked as `-e@custom.yaml`:

* If you do not use ``overcloud_as_undercloud``, pick ``PLAY=oooq-libvirt-provision.yaml``,
  and extract kernel images manually. The command needs to be executed from the host machine:
  ```
  # virt-copy-out -a ${IMAGECACHE}/undercloud.qcow2 \
    /home/stack/overcloud-full.vmlinuz \
    /home/stack/overcloud-full.initrd ${WORKSPACE}
  ```

  Later you'll need to specify the extracted images by adding
  ``-e @/var/tmp/scripts/vars/quickstart-cached-images.yaml`` to deployment commands.

> **NOTE** this might leave you with an oudated kernel, fall back to the
> default ``PLAY=oooq-libvirt-provision-build.yaml`` option then! It
> leverages the ``overcloud_as_undercloud`` magic and you need no to have
> `undercloud.qcow2` at all, the vmlinuz/initrd images will be prepared
> for you by the quickstart libvirt provision roles from the overcloud image
> and used to boot the undercloud VM.

* Copy example data vars ``custom.yaml_example`` as ``custom.yaml`` and check for
  needed data overrides. Note, it contains only common vars for all plays. Use var files
  from the ``vars`` dir (or quickstart's releases configs) for advanced configuration
  overrides. Additional overriding is also possible with ``CUSTOMVARS=something.yaml``
  and ``-e/-e@`` args.

> **NOTE** ``custom.yaml``/``CUSTOMVARS`` applies with each ``create_env_oooq.sh``
> command with the **top level** vars precedence. Do not put there any vars you want
> to override elsewhere, like from the vars files shipped with plays or quickstart's
> releases config files! You can also override ``custom.yaml``/``CUSTOMVARS`` from
> extra files or parameters passed with ``create_env_oooq.sh -e foo=bar -e@baz.yml``.

* Start an interactive wrapper-container session:
	```
	$ ./oooq-warp.sh
	```

* Execute the wanted ``PLAY`` with the command like:
	```
	(oooq) PLAY=something.yaml create_env_oooq.sh -e foo=bar -e@baz.yml -vvvv
	```
	Or you can start the container non-interactively/without a terminal:
	```
	$ PLAY=something.yaml TERMOPTS=-i ./oooq-warp.sh -e foo=bar -e@baz.yml -vvvv
	```

> **NOTE** You can access the undercloud VMs with the command:
> ```
> $ ssh -F ${LWD}/ssh.config.local.ansible undercloud
> ```

### Example playbooks for a local libvirt env ready for OVB setup

WIP (does not really work yet)
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
           -e@/var/tmp/scripts/custom.yaml \
           -e@/var/tmp/scripts/tht/config/general_config/featureset062.yml
```
Add the generated public key into the host's ``USER`` ``authorized_keys`` file.

> **NOTE** The ``dlrn_hash_tag`` value must be matching the version in the
> source URL of the downloaded images. Do not attempt to override
> ``dlrn_hash`` top-scope as it breaks the fact auto-eval in quickstart repo-setup!

* Install undercloud (keeping in mind fs062 for overcloud has top precedence)
```
(oooq) export HOST_BREXT_IP=192.168.23.1
(oooq) ./quickstart.sh -R master -n -I -T none -t all \
           -N config/nodes/1ctlr_1comp.yml \
           -E /var/tmp/scripts/vars/undercloud-local.yaml \
           -E /var/tmp/scripts/custom.yaml \
           -E /var/tmp/scripts/tht/config/general_config/featureset062.yml \
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

> **NOTE** A known issue is that sometimes the docker registry distribution
> dies silently on the undercloud node. You can fix that with starting a custom
> container for the registry like:
> ```
> $ docker run --restart=always -dit -p 8787:5000 \
>       -v /var/lib/docker-registry:/var/lib/registry \
>       --name registry docker.io/library/registry
> ```

```
(oooq) ./quickstart.sh -R master -n -I -T none -t all \
           -S tripleo-validations \
           -p quickstart-extras-overcloud-prep.yml \
           -N config/nodes/1ctlr_1comp.yml \
           -E /var/tmp/scripts/vars/undercloud-local.yaml \
           -E /var/tmp/scripts/custom.yaml \
           -E /var/tmp/scripts/tht/config/general_config/featureset062.yml \
           -e transport=local localhost

(oooq) ./quickstart.sh -R master -n -I -T none -t all \
           -S tripleo-validations \
           -p quickstart-extras-overcloud.yml \
           -N config/nodes/1ctlr_1comp.yml \
           -E /var/tmp/scripts/vars/undercloud-local.yaml \
           -E /var/tmp/scripts/custom.yaml \
           -E /var/tmp/scripts/tht/config/general_config/featureset062.yml \
           -e transport=local localhost
```
> **NOTE** A known issue is that sometimes undercloud node cannot be connected
> because of the missing/bad ``id_rsa_undercloud`` key. Exit and re-enter a new
> wrapper container to fix that.

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
> to re-use the kernel/latest fetched images from
> the ``IMAGECACHEBACKUP`` dir, for example:
> ```
> (oooq) PLAY=oooq-libvirt-provision-build.yaml create_env_oooq.sh \
>            -e@config/nodes/1ctlr_1comp.yml \
>            -e@config/release/master.yml \
>            -e@/var/tmp/scripts/custom.yaml \
>            -e@/var/tmp/scripts/tht/config/general_config/featureset062.yml \
>            -e undercloud_use_custom_boot_images=true \
>            -e undercloud_custom_initrd=${IMAGECACHE}/overcloud-full.initrd \
>            -e undercloud_custom_vmlinuz=${IMAGECACHE}/overcloud-full.vmlinuz \
>            -e force_cached_images=true -e image_cache_expire_days=30
> ```

If you want to include steps like re-fetching remote images and re-building
the kernel images et al, just remove the corresponding images from the
backup dir.

### Example commands for all-in-one undercloud to deploy openshift on top

**Libvirt:**

> **NOTE** Setting ``update_images: true`` is needed to setup root password
> for VM. It drastically extends the image build time! Uncomment
> ``undercloud_use_custom_boot_images``, if you already have kernel images.

```
(oooq) PLAY=oooq-libvirt-provision.yaml create_env_oooq.sh \
           -e@/var/tmp/scripts/tht/config/general_config/featureset127.yml \
           -e update_images=true \
           -e force_cached_images=true -e image_cache_expire_days=300 #\
           #-e undercloud_use_custom_boot_images=true \
           #-e undercloud_custom_initrd=${IMAGECACHE}/overcloud-full.initrd \
           #-e undercloud_custom_vmlinuz=${IMAGECACHE}/overcloud-full.vmlinuz \

(oooq) PLAY=oooq-libvirt-under-openshift.yaml create_env_oooq.sh \
           -e@/var/tmp/scripts/tht/config/general_config/featureset127.yml
```

**Public openstack/RDO cloud**

First, provision a vanilla centos 7.x VM, e.g.:
```
$ openstack server create --image \
    $(openstack image list --long -f value -c ID --property latest=centos-7-latest) \
    --flavor m1.large --key-name <my-public-cloud-key> \
    --nic net-id=<private> --nic net-id=<private2> undercloud

$ openstack floating ip set --port  <id_from_the_private_subnet> <floating_ip>
```
Then generate a static inventory (update ``vars/inventory-traas.yaml`` with
your public cloud creds) and deploy, using a slightly modified command than it
was used above for the example libvirt deployment, like:
```
(oooq) rm -rf $VIRTUAL_ENV/ansible_facts_cache hosts
(oooq) PLAY=oooq-traas.yaml create_env_oooq.sh
(oooq) PLAY=oooq-libvirt-under-openshift.yaml create_env_oooq.sh \
  -e@/var/tmp/scripts/tht/config/general_config/featureset127.yml -v \
  -e undercloud_network_cidr=192.168.253.0/24 \
  -e undercloud_external_network_cidr=192.168.0.0/24 -e \
  undercloud_undercloud_output_dir=/home/centos -e undercloud_user=centos
```
Here 192.168.253.0/24 belongs to my `private2` net, which corresponds to
internal/ctlplane net, and 192.168.0.0/24 - to the `private` net, which is
treated as a "public" net for this example, just to illustrate the network
layout.

### Troubleshooting local libvirt envs

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

As we mount ``/boot`` for libguestfs tools, the kernel image needs to be
world read, so run:
```
# chmod a+r /boot/vmlinuz*
```
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
