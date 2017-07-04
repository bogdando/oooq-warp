#!/bin/bash
# Stub the given user home and ssh setup
# Prepare to run oooq via ansible
set -eu
export WORKON_HOME=~/Envs
USER=${USER:-bogdando}
OOOQE_FORK=${OOOQE_FORK:-openstack}
OOOQE_BRANCH=${OOOQE_BRANCH:-master}
VENV=${VENV:-local}
PLAY=${PLAY:-oooq-libvirt-provision.yaml}
WORKSPACE=${WORKSPACE:-/opt/oooq}
LWD=${LWD:-~/.quickstart}
IMAGECACHE=${IMAGECACHE:-/opt/cache}
TEARDOWN=${TEARDOWN:-true}
INTERACTIVE=${INTERACTIVE:-true}
CONTROLLER_HOSTS=${CONTROLLER_HOSTS:-""}
COMPUTE_HOSTS=${COMPUTE_HOSTS:-""}
SUBNODES_SSH_KEY=${SUBNODES_SSH_KEY:-~/.ssh/id_rsa}
HACK=${HACK:-false}

sudo mkdir -p ${LWD}
sudo chown -R ${USER}: ${LWD}
cd $HOME
if [ "${VENV}" = "local" ]; then
  sudo ln -sf /root/Envs .
  sudo chown -R ${USER}: $HOME
  set +u
  . /usr/bin/virtualenvwrapper.sh
  . ${HOME}/Envs/oooq/bin/activate
  if [[ "$PLAY" =~ "traas" ]]; then
    . /tmp/scripts/ssh_config_nonlocal
  else
    . /tmp/scripts/ssh_config
  fi
  set -u

  # Hack into oooq-extras dev branch
  sudo pip install --upgrade git+https://github.com/${OOOQE_FORK}/tripleo-quickstart-extras@${OOOQE_BRANCH}
  sudo rsync -aLH /usr/config /root/Envs/oooq/
  sudo rsync -aLH /usr/playbooks /root/Envs/oooq/
  sudo rsync -aLH /usr/usr/local/share/ansible/roles /root/Envs/oooq/usr/local/share/ansible/
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
  set -e
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
  echo export HACK=true for an experimental interleaved uc/oc deployment mode
  echo Run create_env_oooq.sh to deploy
  /bin/bash
else
  create_env_oooq.sh
fi
