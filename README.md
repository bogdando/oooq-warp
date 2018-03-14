# A warper for TripleO-QuickStart

An OOOQ wrapper (centos7 container) that makes oooq
thinking it's running at centos, not ubuntu or the like.
While in fact it operates the host's libvirt and nested
kvm, if configured. Just like containerized nova-compute
would do.

It omits shell scripts/featuresets/devmode from OOOQ/tripleo-ci
and only uses an inventory vars and playbooks. As these are
still glued by a shell script, you can as well invoke wanted
``ansible-playbook`` commands directly, if you wish so.

WIP: It may be used to deploy with traas and openstack provider
and pre-provisioned VMs (see tripleo's deployed-server).

## Requirements for the host OS

* Packer >= 0.12
* Docker >= 1.13
* Libvirt and kvm (latest perhaps) with HW access/nested
  virtualization enabled, for local deployments

For non local (traas) deployments:
* OpenStack cloud >= Ocata with Heat
* OpenStack client installed locally
* OpenStack creds file and pem/pub key files to access the hosting cloud

> **NOTE** public cloud providers may not allow HW enabled kvm. OOOQ
> will not work on QEMU, sorry!

Note, the wrapper docker image wants Ansible >= 2.3, Shade >= 1.21.0
and Jinja >= 2.9.6, plus those oooq/extras requirements and packages
that come from the oooq repo's master branch. Feel free to rebuild it
to update installed versions.

## Build the wrapper container
```
$ packer build packer-docker-centos7.json
$ packer build packer-docker-oooq-runner.json
```
Note, adapt those for your case or jut use existing images. It also requires
``OOOQ_PATH`` set and pointing to the quickstart clonned locally.

## Pre-flight checks for a warp jump

To start a scratch local dev env with libvirt and kvm:

* Download overcloud/undercloud images and md5 into the ``IMAGECACHE``.

  > **WARN**: Backup those for future re-provision runs!
  > Quickstart will mutate qcow2 files in-place, so
  > for a clean retry you will need those restored from a backup manually.

  For master dev envs, you may want to pick any of these sources:
  * [The most recent, the less stable](https://images.rdoproject.org/master/delorean/current-tripleo/),
    for hardcore devs
  * [The consistent, the longest upgrade path](http://artifacts.ci.centos.org/rdo/images/master/delorean/consistent/),
    it is also the default OOOQ choice (a [mirror](https://images.rdoproject.org/master/delorean/consistent/)).
  * [The one from](https://buildlogs.centos.org/centos/7/cloud/x86_64/tripleo_images/master/delorean/) the
    [docs](http://tripleo.org/basic_deployment/basic_deployment_cli.html), for RTFM ppl.
* Export env vars as you want them, for example:
  ```
  $ export USER=bogdando
  $ export WORKSPACE=/tmp/qs #persisted on host, libvirt revers to it
  $ export IMAGECACHE=/opt/cache #persistent on host
  $ export LWD=${HOME}/.quickstart #persistent on host
  $ export OOOQE_BRANCH=dev
  $ export OOOQE_FORK=johndoe
  $ export OOOQ_BRANCH=dev
  $ export OOOQ_FORK=johbdoe
  ```
  Or use ``OOOQE_PATH`` and/or ``OOOQ_PATH``, if you want omit clonning either of
  the quickstart or extras repo and use the local copies instead.
* Export a custom ``PLAY`` and/or ``CUSTOMVARS`` names to start with. The default play is
  is ``oooq-libvirt-provision.yaml`` (see the `playbooks` dir) and the default
  overrides file is invoked as `-e@custom.yaml`:
  ```
  $ export PLAY=oooq-libvirt-under.yaml
  ```
* Extract initrd and vmlinuz (from the host, does not work from the
  wrapping oooq-runner container):
  ```
  # virt-copy-out -a ${IMAGECACHE}/undercloud.qcow2 \
    /home/stack/overcloud-full.vmlinuz \
    /home/stack/overcloud-full.initrd ${WORKSPACE}
  ```
  This step may be omitted if building images with quickstart.

* Prepare host for nested kvm and do some sysctl magic:
  ```
  # echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
  # modprobe -r kvm_intel
  # modprobe kvm_intel
  # cat /sys/module/kvm_intel/parameters/nested
  # echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables
  ```
  The latter step is optional, ignore if the command fails.

* Copy example data vars ``custom.yaml_example`` as ``custom.yaml`` and check for
  needed data overrides. Note, it contains only common vars for all plays. Use var files
  from the ``vars`` dir (or quickstart's releases configs) for advanced configuration
  overrides. Arbitrary overrides are also supported with ``CUSTOMVARS=something.yaml``.

  > **NOTE** ``custom.yaml``/``CUSTOMVARS`` applies with each ``create_env_oooq.sh``
  command with the top level vars precedence. Do not put there any vars you want
  to override elsewhere, like from the vars files shipped with plays or releases configs!

* (optional) Git checkout the wanted branches of the local quickstart/extras repos.
  Controlled by the given ``OOOQ_PATH`` and ``OOQE_PATH``. If not set, then those
  are git clonned from ``OOOQ(E)_FORK/BRANCH``.

For traas, provision servers with the openstack CLI and proceed with custom
playbooks as it's described below.

For libvirt deployments w/o overclouds, provision your only undercloud VM with
the command like:
```
(oooq) PLAY=oooq-libvirt-provision.yaml create_env_oooq.sh
```

You can access the undercloud VMs with the command:
```
ssh -F /opt/.quickstart/ssh.config.local.ansible undercloud
```

> **NOTE** That command reuses the extracted initrd/vmlinuz kernel images and
> omits the repo-setup and some of the qcow2 image building steps are normally
> executed with quickstart CI. If the extracted kernel images do not fit your
> case, use ``oooq-libvirt-provision-build.yaml`` instead.

## Example playbooks for a local libvirt env ready for OVB setup

The expected workflow is:

* provision a libvirt env, it creates a running undercloud VM and shut-off VMs
  from the ``overcloud_nodes`` passed.
* Install undercloud as a separate step (optional, depends on the next step)
* Deploy a particular quickstart's CI featureset, given a nodes-file and/or a
  config release file, added your custom ansible CLI args and ``CUSTOMVARS``.
* Proceed with OVB, f.e. executred from the provided ``reproduce-quickstart.sh``.

Example commands (``(oooq)`` represents the shell prompt in the oooq container):

* Provision with building images
```
(oooq) ./quickstart.sh --install-deps
(oooq) PLAY=oooq-libvirt-provision-build.yaml create_env_oooq.sh \
           -e@config/nodes/1ctlr_1comp.yml -e@config/release/master.yml
```
* Install undercloud (keeping in mind the fs062 featureset for overcloud)
```
(oooq) export HOST_BREXT_IP=192.168.23.1
(oooq) ./quickstart.sh -R master -n -I -T none -t all \
           -N config/nodes/1ctlr_1comp.yml \
           -E /tmp/scripts/tht/config/general_config/featureset062.yml \
           -E /tmp/scripts/vars/undercloud-local.yaml \
           -p quickstart-extras-undercloud.yml \
           -e transport=local \
           -e vbmc_libvirt_uri="qemu+ssh://${USER}@${HOST_BREXT_IP}/session?socket=/run/libvirt/libvirt-sock&keyfile=${LWD}/id_rsa_virt_power&no_verify=1&no_tty=1" \
           localhost
```
**FIXME**: the socket path is hardcoded in quickstart for RHEL OS family,
so we have to override the ``vbmc_libvirt_uri`` and manually evaluate ``HOST_BREXT_IP``.

* Deploy overcloud from the given featureset and nodes config
```
(oooq) ./quickstart.sh -R master -n -I -T none -t all \
           -S tripleo-validations \
           -p quickstart-extras-overcloud-prep.yml \
           -N config/nodes/1ctlr_1comp.yml \
           -E /tmp/scripts/tht/config/general_config/featureset062.yml \
           -E /tmp/scripts/vars/undercloud-local.yaml \
           -e transport=local localhost

(oooq) ./quickstart.sh -R master -n -I -T none -t all \
           -S tripleo-validations \
           -p quickstart-extras-overcloud.yml \
           -N config/nodes/1ctlr_1comp.yml \
           -E /tmp/scripts/tht/config/general_config/featureset062.yml \
           -E /tmp/scripts/vars/undercloud-local.yaml \
           -e transport=local localhost
```
* Deploy your OVB setup on top

## Dev branches and venvs (undercloud)

By default, the wrapper uses predefined python virtual env named oooq.
Container build time, upstream dependencies are installed into it.
Quickstart extras is installed from the given fork and branch params:
```
pip install git+https://github.com/johndoe/tripleo-quickstart-extras@dev
```

For remaining components, like t-h-t, puppet modules, tripleo client,
define a custom repo/branch/refspec:
```
overcloud_templates_repo: https://github.com/johndoe/tripleo-heat-templates
overcloud_templates_branch: dev
undercloud_install_script: undercloud-deploy-dev.sh.j2
```
Then opionally create a custom ``undercloud-deploy-dev.sh.j2`` script.
Inside, make sure to checkout/install required dev branches of components under
dev/test. Then define a composable role (a heat environemnt) for the undercloud
for the given script as well. For overcloud custom roles, see OOOQ docs.

You may want as well to use default deployment script and t-h-t et al installed
from packages. For that case you can still provide your custom t-h-t env files
in the `tht/environments` directory. Those will be uploaded to the undercloud
node and can be picked as extra deployment args from
`{{working_dir}}/tht/environments`.

## Respinning a failed local libvirt env

If you want to reuse existing customized by oooq images and omit
all of the long playing oooq provisioning steps:
* Export ``TEARDOWN=false`` then rerun the deploy inside of the
  container.

To start a new libvirt env from the scratch:

* remove existing VMs' snapshots,
* restore the downloaded images from backups to the ``IMAGECACHE`` dir,
* exit the wrapper container,
* start a new container with ``TEARDOWN=true ./oooq-warp.sh`` or the like.

## Troubleshooting local envs

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

## Traas multinode pre-provisioned deployment with openstack provider

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
