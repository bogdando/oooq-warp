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
* OpenStack cloud >= Ocata with Heat, for non local (traas) deployments

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

* Download overcloud/undercloud images and md5 into the ``IMAGECACHE``.
  For master dev envs, you may want to pick any of these sources:
  * [The most recent, the less stable](http://artifacts.ci.centos.org/rdo/images/master/delorean/current-tripleo/testing/),
    for hardcore devs (a [mirror](https://images.rdoproject.org/master/delorean/current-tripleo/testing/))
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
  $ export LWD=/home/{USER}/.quickstart
  $ export OOOQE_BRANCH=dev
  $ export OOOQE_FORK=johndoe
  $ export VENV=hostpath
  $ export VPATH=${HOME}/.venvs/oooq
  # mkdir -p ${WORKSPACE}
  ```
* Export a custom PLAY name to start with. The default play is
  is ``oooq-libvirt-provision.yaml`` (see the `playbooks` dir):
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

* Copy data vars ``custom.yaml_example`` as ``custom.yaml`` and check for
  needed data overrides. Note, it contains only common vars. Use var files
  from the ``vars`` dir for advanced configuration overrides.
* Git checkout the wanted branch of the local OOQ repo. It will be mounted
  into the wrapper container by the given ``OOOQ_PATH``.

For traas, provision servers with the openstack CLI and proceed with custom
playbooks as it's described below.

## Example playbooks for a local libvirt env

An example list of the executed plays:
* the default ``oooq-libvirt-provision.yaml``, that provisions servers and
  updates inventory. Use ``TEARDOWN=false`` to omit it.
* the ``oooq-libvirt-under.yaml`` or an arbitrary custom ``PLAY``.

Use ``INTERACTIVE=false`` to start the chosen ``PLAY`` automatically after the
provisioning steps done. Otherwise, it returns to the shell prompt of the
wrapper container. The interactive mode may help debugging.

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

TODO: overcloud dev branches

By default, the wrapper uses predefined python virtual env named oooq.
Container build time, upstream dependencies are installed into it.
If you want to mount in your custom venv, configure as in the example
above. That env must contain at least oooq and oooq-extras dependencies.

An alternative shortcut for overriding only OOOQ-extras playbooks and roles,
is to use ``VENV=local`` and override its stock setup by the env vars
``OOOQE_BRANCH`` and ``OOOQE_FORK``. For the given above example, it would do:
```
pip install git+https://github.com/johndoe/tripleo-quickstart-extras@dev
```
right into the local oooq venv at the container entry point stage.


For the rest of components, like t-h-t, puppet modules, heat-agent,
define a custom repo/branch/refspec:
```
overcloud_templates_repo: https://github.com/johndoe/tripleo-heat-templates
overcloud_templates_branch: dev
undercloud_install_script: undercloud-deploy-dev.sh.j2
```
Then create the custom ``undercloud-deploy-dev.sh.j2`` script.
Inside, make sure to checkout/install required dev branches of components under
dev/test. Then define a composable role (a heat environemnt) for the undercloud
for the given script as well. For overcloud custom roles, see OOOQ docs.

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
# sudo systemctl restart libvirt-bin
# sudo systemctl restart qemu-kvm
```

## Traas multinode pre-provisioned deployment with openstack provider

Note that you should disable Neutron ports security for pre-provisioned VMs
running at the host cloud as an overcloud deployment prerequisite:
```
neutron port-update --no-security-groups $PORT
neutron port-update  $PORT --port-security-enabled=False
```

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
