#!/var/tmp/Envs/oooq/bin/dumb-init /bin/bash
# Stub the given user home and ssh setup
# Prepare to run oooq via ansible
set -eu
[ "${SUPERMIN_KERNEL:-}" ] || unset SUPERMIN_KERNEL
[ "${SUPERMIN_MODULES:-}" ] || unset SUPERMIN_MODULES
[ "${SUPERMIN_KERNEL_VERSION:-}" ] || unset SUPERMIN_KERNEL_VERSION
[ "${CONTROLLER_HOSTS:-}" ] || unset CONTROLLER_HOSTS
[ "${COMPUTE_HOSTS:-}" ] || unset COMPUTE_HOSTS
[ "${OOOQ_PATH:-}" ] || unset OOOQ_PATH
[ "${OOOQE_PATH:-}" ] || unset OOOQE_PATH
[ "${HOST_BREXT_IP:-}" ] || unset HOST_BREXT_IP
export PS1='$ '
export WORKON_HOME=$VPATH
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python
export VIRTUALENVWRAPPER_HOOK_DIR=$WORKON_HOME
export ARGS="${@:-}"
sudo cp -f ${SCRIPTS_WORKPATH}/*.sh /usr/local/sbin/ 2>/dev/null ||:
sudo chmod +x /usr/local/sbin/* 2>/dev/null ||:

# Ensure the wanted user setup
sudo useradd -m -p '' -G wheel -U ${USER}||:
sudo mkdir -p /home/${USER} /home/${USER}/.ssh
echo "${USER} ALL=NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${USER}
echo "Defaults:${USER} !requiretty" | sudo tee -a /etc/sudoers.d/${USER}
sudo chmod 0440 /etc/sudoers.d/${USER}
echo 'export WORKON_HOME=/home/${USER}/Envs' | sudo tee /home/${USER}/.bashrc
echo 'export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python' | sudo tee -a /home/${USER}/.bashrc
echo '. /usr/bin/virtualenvwrapper.sh' | sudo tee -a /home/${USER}/.bashrc

# FIXME: hack the venv as quickstart --botstrap/--clean knows/recognizes it
sudo ln -sf ${VPATH} ${HOME}/
sudo rm -rf "${LWD}/config" "${LWD}/playbooks"
sudo ln -sf ${VPATH}/oooq/* "${LWD}/"

for p in $KNOWN_PATHS /home/${USER}; do
  [ "$p" = "${VPATH}/oooq" ] && continue
  echo "Chowning images cache and working dirs for ${p} (may take a while)..."
  sudo mkdir -p ${p}
  sudo chown -R ${USER}:${USER} ${p}
done

cd $HOME
. /usr/bin/virtualenvwrapper.sh
. ${VPATH}/oooq/bin/activate
[[ "$PLAY" =~ "libvirt" ]] && (. ${SCRIPTS_WORKPATH}/ssh_config)

# Note we pick the hacked in paths in the custom ansible.cfg bind-mounted
if [ -z ${OOOQ_PATH} ]; then
  # Hack into oooq dev branch
  sudo pip install --upgrade git+https://github.com/${OOOQE_FORK}/tripleo-quickstart@${OOOQE_BRANCH}
  sudo rsync -aLH /usr/config "${LWD}"
  sudo rsync -aLH /usr/playbooks "${LWD}"
  sudo rsync -aLH /usr/local/share/tripleo-quickstart/roles "${LWD}"
  sudo rsync -aLH /usr/local/share/tripleo-quickstart/library "${LWD}"
  sudo rsync -aLH /usr/local/share/tripleo-quickstart/test_plugins "${LWD}"
elif [ "$LWD" != "$OOOQ_WORKPATH" ]; then
  # Place the local git repo under the work path
  sudo rsync -aLH $OOOQ_WORKPATH/config "${LWD}"
  sudo rsync -aLH $OOOQ_WORKPATH/playbooks "${LWD}"
  sudo rsync -aLH $OOOQ_WORKPATH/roles "${LWD}"
  sudo rsync -aLH $OOOQ_WORKPATH/library "${LWD}"
  sudo rsync -aLH $OOOQ_WORKPATH/test_plugins "${LWD}"
fi

if [ -z ${OOOQE_PATH} ]; then
  # Hack into oooq-extras dev branch
  sudo pip install --upgrade git+https://github.com/${OOOQE_FORK}/tripleo-quickstart-extras@${OOOQE_BRANCH}
  sudo rsync -aLH /usr/config "${LWD}"
  sudo rsync -aLH /usr/playbooks "${LWD}"
  sudo rsync -aLH /usr/local/share/ansible/roles "${LWD}"
else
  # Place the local git repo under the work path
  sudo rsync -aLH $OOOQE_WORKPATH/config "${LWD}"
  sudo rsync -aLH $OOOQE_WORKPATH/playbooks "${LWD}"
  sudo rsync -aLH $OOOQE_WORKPATH/roles "${LWD}"
fi
for p in $KNOWN_PATHS; do
  [ "$p" = "${VPATH}/oooq" -o "$p" = "$HOME" ] && continue
  sudo chown -R ${USER}:${USER} ${p}
done

set +ex
# Restore the saved state spread across LWD/WORKSPACE/IMAGECACHE dirs
# (ssh keys/setup, inventory, kernel images et al)
if [ "${TEARDOWN}" = "false" ]; then
  echo "Restoring state (syncing across known LWD/WORKSPACE/IMAGECACHE paths)"
  save-state.sh --sync
  sudo mkdir -p /etc/ansible
  sudo cp -f "${LWD}/hosts" /etc/ansible/ 2>/dev/null
else
  echo "Cleaning up state as TEARDOWN was requested"
  save-state.sh --purge
  rm -f "${LWD}"_deploy.log "${LWD}"_deploy_nice.log
  if [ "${IMAGECACHEBACKUP:-}" ]; then
    echo "Restoring all files from backup ${IMAGECACHEBACKUP} dir to ${IMAGECACHE}"
    cp -af ${IMAGECACHEBACKUP}/* ${IMAGECACHE}
  fi
fi

# Regenerate the latest-* images from the existing state
if [ -f ${IMAGECACHE}/undercloud.qcow2 -a -f ${IMAGECACHE}/undercloud.qcow2.md5 ]; then
  echo "Symlinking the latest undercloud images from restored md5 hashes"
  iname=$(cat ${IMAGECACHE}/undercloud.qcow2.md5 | awk '{print $1}')
  ln -f ${IMAGECACHE}/undercloud.qcow2 ${IMAGECACHE}/${iname}.qcow2
  ln -sf ${IMAGECACHE}/${iname}.qcow2 ${IMAGECACHE}/latest-undercloud.qcow2
fi
if [ -f ${IMAGECACHE}/overcloud-full.tar -a -f ${IMAGECACHE}/overcloud-full.tar.md5 ]; then
  echo "Symlinking the latest overcloud images from restored md5 hashes"
  iname=$(cat ${IMAGECACHE}/overcloud-full.tar.md5 | awk '{print $1}')
  ln -f ${IMAGECACHE}/overcloud-full.tar ${IMAGECACHE}/${iname}.tar
  ln -sf ${IMAGECACHE}/${iname}.tar ${IMAGECACHE}/latest-overcloud-full.tar
fi
if [ -f ${IMAGECACHE}/ironic-python-agent.tar -a -f ${IMAGECACHE}/ironic-python-agent.tar.md5 ]; then
  echo "Symlinking the latest ipa images from restored md5 hashes"
  iname=$(cat ${IMAGECACHE}/ironic-python-agent.tar.md5 | awk '{print $1}')
  ln -f ${IMAGECACHE}/ironic-python-agent.tar ${IMAGECACHE}/${iname}.tar
  ln -sf ${IMAGECACHE}/${iname}.tar ${IMAGECACHE}/latest-ipa_images.tar
fi

# FIXME: better processing than having IMAGECACHEBACKUP=/opt/cache.back hardcoded?
if [ "${IMAGECACHEBACKUP:-}" ]; then
  centos_latest=$(find ${IMAGECACHEBACKUP} -type f -regextype posix-extended -regex "\/opt\/cache\.bak\/[^liou].*")
  if [ "$centos_latest" ]; then
    echo "Symlinking the latest centos image from restored md5 hashes"
    centos_latest=${centos_latest##*/}
    ln -sf ${IMAGECACHE}/${centos_latest} ${IMAGECACHE}/latest-centos.qcow2
  fi
fi
# Silent sync for the regenerated hardlinks
save-state.sh --sync 2>&1 > /dev/null

if [[ "$TERMOPTS" =~ "t" ]]; then
cd "${LWD}"
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
  echo ================================================================================================
  echo Or use quickstart.sh as usual - that requires manual saving for any produced state,
  echo "like 'save-state.sh --sync' or 'save-state.sh \$LWD/\$WORKSPACE/\$IMAGECACHE'"
  echo "Use 'save-state.sh --purge' to nuke all the saved quickstart state but in \$IMAGECACHEBACKUP"
  /bin/bash
else
  if [ "$USE_QUICKSTART_WRAP" = "false" ]; then
    create_env_oooq.sh $ARGS
  else
    quickstart.sh --install-deps
    quickstart.sh $ARGS
  fi
fi
