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

sudo mkdir -p /tmp/oooq
sudo mkdir -p ${LWD}
sudo chown -R ${USER}: ${LWD}
sudo mkdir -p ${WORKSPACE}
sudo chown -R ${USER}: ${WORKSPACE}
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

# Restore the saved state spread across LWD/WORKSPACE dirs
# (ssh keys/setup, inventory, kernel images)
if [ "${TEARDOWN}" = "false" ]; then
  set +ex
  for state in 'id_rsa_undercloud' 'id_rsa_virt_power' \
      'id_rsa_undercloud.pub' 'id_rsa_virt_power.pub' ; do
    cp -f "${WORKSPACE}/${state}" ${LWD}/
  done
  for state in 'hosts' 'ssh.config.ansible' \
      'ssh.config.local.ansible' ; do
    cp -f "${LWD}/${state}" ${WORKSPACE}/
  done
  sudo mkdir -p /etc/ansible
  sudo cp -f "${LWD}/hosts" /etc/ansible/
  cp -f "${LWD}/hosts" /tmp/oooq/
  set -ex
else
  rm -f "${WORKSPACE}/{id_rsa,hosts,ssh.config}*"
  rm -f "${LWD}/{id_rsa,hosts,ssh.config}*"
  if [ "${IMAGECACHEBACKUP:-}" ]; then
   echo "Restoring all files from backup ${IMAGECACHEBACKUP} dir to ${IMAGECACHE}"
   cp -a ${IMAGECACHEBACKUP}/* ${IMAGECACHE}
  fi
fi


sudo chown -R ${USER}: ${HOME}
cd /tmp/oooq
echo Note: ansible virthost is now localhost
echo export PLAY=oooq-libvirt-provision.yaml to bootstrap undercloud and generate inventory - default
echo export PLAY=oooq-libvirt-provision-build.yaml if you plan to continue with overcloud deployments
echo export PLAY=oooq-libvirt-under.yaml to deploy only an undercloud
echo export TEARDOWN=false respin a failed local deployment omitting build/provision tasks
echo ================================================================================================
echo export PLAY=oooq-traas.yaml to generate inventory for existing openstack VMs
echo export PLAY=oooq-traas-under.yaml to deploy an undercloud on openstack
echo export PLAY=oooq-traas-over.yaml to deploy an overcloud on on openstack
echo export PLAY=oooq-traas-kubespray.yaml to prepare overcloud for k8s on openstack
echo ================================================================================================
echo export CUSTOMVARS=path/file.yaml to override default '-e @custom.yaml' with it
echo Run create_env_oooq.sh added optional args, to either provision or to deploy on top!
/bin/bash
