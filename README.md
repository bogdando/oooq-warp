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

Note, public cloud providers may not allow HW enabled kvm. OOOQ
will not work on QEMU, sorry!

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
``OOOQ_PATH`` set, see below.

## Pre-flight checks for a warp jump

To start a scratch local dev env with libvirt and kvm:

* Download overcloud/undercloud images and md5 into the ``IMAGECACHE``. Backup
  those for future re-provision runs! Quickstart will mutate qcow2 files in-place, so
  for a clean retry you will need those restored from a backup.
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
  $ export OOOQ_PATH=${HOME}/gitrepos/tripleo-quickstart
  $ export WORKSPACE=/opt/oooq
  $ export IMAGECACHE=/opt/cache
  $ export LWD=${HOME}/.quickstart
  $ export OOOQE_BRANCH=dev
  $ export OOOQE_FORK=johndoe
  $ export OOOQ_BRANCH=dev
  $ export OOOQ_FORK=johbdoe
  # mkdir -p ${WORKSPACE}
  ```
  Or use ``OOOQE_PATH`` and/or ``OOOQ_PATH``, if you want omit clonning either of
  the quickstart or extras repo and use local copies instead.
* Export a custom PLAY and/or CUSTOMVARS names to start with. The default play is
  is ``oooq-libvirt-provision.yaml`` (see the `playbooks` dir) and the default
  overrides file is invoked as `-e@custom.yaml`:
  ```
  $ export PLAY=oooq-libvirt-under.yaml
  ```
* Extract initrd and vmlinuz (does not work from the
  wrapping oooq-runner container):
  ```
  # virt-copy-out -a ${IMAGECACHE}/undercloud.qcow2 \
    /home/stack/overcloud-full.vmlinuz \
    /home/stack/overcloud-full.initrd ${WORKSPACE}
  ```
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
  needed data overrides. Note, it contains only common vars. Use var files
  from the ``vars`` dir for advanced configuration overrides. You can either
  copy it as ``custom.yaml`` or ``export CUSTOMVARS=vars/something.yaml``.
* (optional) Git checkout the wanted branches of the local OOQ(E) repos. Controlled
  by the given ``OOOQ_PATH`` and ``OOQE_PATH``. If not set, then those are git
  clonned from OOOQ(E) FORK/BRANCH.

For traas, provision servers with the openstack CLI and proceed with custom
playbooks as it's described below.

For libvirt deployments w/o overclouds, provision VMs with the command like:
```
(oooq) PLAY=oooq-libvirt-provision.yaml create_env_oooq.sh
```

## Example playbooks for a local libvirt env ready for OVB setup

An example list of the executed plays:
* the default ``oooq-libvirt-provision.yaml``, that provisions servers and
  updates inventory. Use ``TEARDOWN=false`` to omit it.
* the ``oooq-libvirt-under.yaml`` or an arbitrary custom ``PLAY``.

Use ``INTERACTIVE=false`` to start the chosen ``PLAY`` automatically after the
provisioning steps done. Otherwise, it returns to the shell prompt of the
wrapper container. The interactive mode may help debugging.

An example commands:
```
(oooq) PLAY=oooq-libvirt-provision-build.yaml create_env_oooq.sh \
-e@config/nodes/1ctlr_1comp.yml -e@config/release/master.yml
(oooq) export OOOQ_DIR=$PWD
(oooq) export OPT_WORKDIR=$PWD
(oooq) ./quickstart.sh --install-deps
```
(install undercloud keeping in mind an arbitrary CI featureset for overcloud)
```
(oooq) ./quickstart.sh -R master -n -I -T none -t all \
-N config/nodes/1ctlr_1comp.yml \
-E /tmp/scripts/tht/config/general_config/featureset062.yml \
-p quickstart-extras-undercloud.yml \
-e transport=local -e inventory=hosts localhost
```
TODO: the latter command might not always pick the generated inventory. If so,
then use the ansible-playbook command it produces, yet added ``-i hosts``.

(deploy that CI featureset as overcloud)
```
(oooq) #TBD
```

## Hacking mode with interleaving undercloud/overcloud tasks (experimental)

Use ``HACK=true`` to overlap undercloud and overcloud install playbooks for some
point. While hacky and racy and will likely fail, it can still be a shortcut for
the total deploy time. The long running steps, like populating container images
to prepare the overcloud deployment, save *a lot* of time when overlapped with
the undercloud deployment tasks. And failed playbooks may be just re-applied,
after all!

It should only be used with the ``INTERACTIVE=true`` as it requires manual
steps to finish deployments, like turning off the hack mode and retrying of the
failed playbooks.

This mode is only works with traas playbooks yet.

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
* Make sure your ``local_working_dir`` is a persistent host path
  Otherwise, when the container exited, you loose the updated
  inventory and ssh keys and may only start from the scratch.
* Export ``TEARDOWN=false`` then rerun the deploy inside of the
  container.

To start from the scratch, remove existing VMs' snapshots, export or
unset``TEARDOWN=true``, unset ``PLAY``, exit container and re-run
``./oooq-warp.sh`` and grap some cofee, it won't be ready soon.

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

Note, the private key from the generated Nova keypair should be copied under
``$WORKSPACE``.

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
into the wrapper container and may be not ephemeral, so take care of your
secrets to not be spreading around permanently!

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

The `custom.yaml_defaults` also provides some top level overrides
for oooq roles' vars. Those are needed to reify multinode/deployed-server
networking.
