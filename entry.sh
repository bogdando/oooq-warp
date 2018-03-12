#!/bin/bash
# Stub the given user home and ssh setup
# Prepare to run oooq via ansible
set -eu
export WORKON_HOME=~/Envs
USER=${USER:-bogdando}
OOOQ_PATH=${OOOQ_PATH:-}
OOOQ_FORK=${OOOQ_FORK:-openstack}
OOOQ_BRANCH=${OOOQ_BRANCH:-master}
OOOQE_PATH=${OOOQE_PATH:-}
OOOQE_FORK=${OOOQE_FORK:-openstack}
OOOQE_BRANCH=${OOOQE_BRANCH:-master}
VPATH=${VPATH:-/root/Envs}
PLAY=${PLAY:-oooq-libvirt-provision.yaml}
WORKSPACE=${WORKSPACE:-/opt/oooq}
LWD=${LWD:-~/.quickstart}
TEARDOWN=${TEARDOWN:-true}
INTERACTIVE=${INTERACTIVE:-true}

sudo mkdir -p /tmp/oooq
sudo mkdir -p ${LWD}
sudo chown -R ${USER}: ${LWD}
cd $HOME
sudo ln -sf ${VPATH} .
sudo chown -R ${USER}: $HOME
set +u
. /usr/bin/virtualenvwrapper.sh
. ${VPATH}/oooq/bin/activate
[[ "$PLAY" =~ "libvirt" ]] && (. /tmp/scripts/ssh_config)
set -u

if [ -z ${OOOQ_PATH} ]; then
  # Hack into oooq dev branch
  sudo pip install --upgrade git+https://github.com/${OOOQE_FORK}/tripleo-quickstart@${OOOQE_BRANCH}
  sudo rsync -aLH /usr/config /tmp/oooq/
  sudo rsync -aLH /usr/playbooks /tmp/oooq/
  sudo rsync -aLH /usr/local/share/tripleo-quickstart/roles /tmp/oooq/
  sudo rsync -aLH /usr/local/share/tripleo-quickstart/library /tmp/oooq/
  sudo rsync -aLH /usr/local/share/tripleo-quickstart/test_plugins /tmp/oooq/
fi

if [ -z ${OOOQE_PATH} ]; then
  # Hack into oooq-extras dev branch
  sudo pip install --upgrade git+https://github.com/${OOOQE_FORK}/tripleo-quickstart-extras@${OOOQE_BRANCH}
  sudo rsync -aLH /usr/config /tmp/oooq/
  sudo rsync -aLH /usr/playbooks /tmp/oooq/
  sudo rsync -aLH /usr/local/share/ansible/roles /tmp/oooq/
else
  sudo rsync -aLH /tmp/oooq-extras/config /tmp/oooq/
  sudo rsync -aLH /tmp/oooq-extras/playbooks /tmp/oooq/
  sudo rsync -aLH /tmp/oooq-extras/roles /tmp/oooq/
fi

# Restore the saved state from the WORKSPACE (ssh keys/setup, inventory)
# to allow fast respinning of the local environment omitting VM provisioning tasks
if [ "${TEARDOWN}" = "false" ]; then
  set +e
  for state in 'hosts' 'id_rsa_undercloud' 'id_rsa_virt_power' \
      'id_rsa_undercloud.pub' 'id_rsa_virt_power.pub' \
      'ssh.config.ansible' 'ssh.config.local.ansible'; do
    sudo cp -f "${WORKSPACE}/${state}" ${LWD}/
  done
  sudo mkdir -p /etc/ansible
  sudo cp -f "${WORKSPACE}/hosts" ${LWD}/hosts
  sudo cp -f "${WORKSPACE}/hosts" /etc/ansible/
  set -e
else
  rm -f /opt/oooq/{id_rsa,hosts,ssh.config}*
fi

sudo chown -R ${USER}: ${HOME}
cd /tmp/oooq
if [ "$INTERACTIVE" = "true" ]; then
  echo Note: ansible virthost is now localhost
  echo export PLAY=oooq-libvirt-provision.yaml to bootstrap local VMs and generate inventory - default choice
  echo export PLAY=oooq-libvirt-under.yaml to deploy only an undercloud locally
  echo export TEARDOWN=false respin a failed local deployment omitting VMs provisioning tasks
  echo =================================================================================================
  echo export PLAY=oooq-traas.yaml to generate inventory for existing openstack VMs
  echo export PLAY=oooq-traas-under.yaml to deploy an undercloud on openstack
  echo export PLAY=oooq-traas-over.yaml to deploy an overcloud on on openstack
  echo export PLAY=oooq-traas-kubespray.yaml to prepare overcloud for k8s on openstack
  echo export HACK=true for an experimental interleaved uc/oc deployment mode
  echo export CUSTOMVARS=path/file.yaml to override default '-e @custom.yaml' with it
  echo Run create_env_oooq.sh to deploy
  /bin/bash
else
  create_env_oooq.sh
fi
