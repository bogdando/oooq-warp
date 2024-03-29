#!/var/tmp/Envs/oooq/bin/dumb-init /bin/bash
# Stub the given user home and ssh setup
# Prepare to run oooq via ansible
set -eu
[ "${SUPERMIN_KERNEL:-}" ] || unset SUPERMIN_KERNEL
[ "${SUPERMIN_MODULES:-}" ] || unset SUPERMIN_MODULES
[ "${SUPERMIN_KERNEL_VERSION:-}" ] || unset SUPERMIN_KERNEL_VERSION
[ "${OOOQ_PATH:-}" ] || unset OOOQ_PATH
[ "${OOOQE_PATH:-}" ] || unset OOOQE_PATH
[ "${HOST_BREXT_IP:-}" ] || unset HOST_BREXT_IP
export PS1='$ '
export WORKON_HOME=$VPATH
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python
export VIRTUALENVWRAPPER_HOOK_DIR=$WORKON_HOME
export ARGS="${@:-}"
export ANSIBLE_LOG_PATH=ansible.log
export ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3
export ANSIBLE_INVENTORY=${LWD}/tripleo-ci-reproducer/hosts
export ANSIBLE_CONFIG=${OOOQ_WORKPATH}/ansible.cfg

set +e
sudo cp -f ${SCRIPTS_WORKPATH}/*.sh /usr/local/sbin/ 2>/dev/null
sudo chmod +x /usr/local/sbin/* 2>/dev/null
sudo chmod a+rw -R ${LWD}/tripleo-ci-reproducer
sudo chmod a+rw /home/${USER}/.config/openstack
sudo chmod a+rw /var/lib/zuul

# Ensure the wanted user setup
if [ "${UMOUNTS:-}" = "donkeys" ]; then
  sudo useradd -p '' -G wheel -U ${USER} -u 1000
  echo "donkey ALL=NOPASSWD:ALL" >> /etc/sudoers
  sed -rin '/^libvirt/d' /etc/group
  sed -rin '/^kvm/d' /etc/group
  sed -rin '/^input:/d' /etc/group
  echo "docker:x:${KVMGID}:donkey" >> /etc/group
  echo "docker:x:${DOCKERGID}:donkey" >> /etc/group
  echo "libvirt:x:${LIBVIRTGID}:donkey" >> /etc/group
else
  sudo useradd -p '' -G wheel -U ${USER}
  sudo useradd -p '' -G kvm -U ${USER}
  sudo useradd -p '' -G docker -U ${USER}
  sudo useradd -p '' -G libvirt -U ${USER}
fi
if [ ! -h "${HOME}" ]; then
  mkdir -p ${LWD}/.ssh
  sudo mkdir -p ${HOME}
  sudo chown -R ${USER}:${USER} ${HOME}
  ln -sf ${LWD}/.ssh ${HOME}/
  sudo ln -sf ${HOME} /home/zuul
else
  sudo chown -R ${USER}:${USER} ${LWD}
  sudo ln -sf ${LWD} ${HOME}
  sudo ln -sf ${LWD} /home/zuul
fi
set -e

echo "${USER} ALL=NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${USER}
echo "Defaults:${USER} !requiretty" | sudo tee -a /etc/sudoers.d/${USER}
sudo chmod 0440 /etc/sudoers.d/${USER}
echo 'export WORKON_HOME=${HOME}/Envs' >> ${HOME}/.bashrc
echo 'export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python' >> ${HOME}/.bashrc

# FIXME: hack the venv as quickstart --botstrap/--clean knows/recognizes it
rm -rf "${HOME}/etc"
rm -rf "${LWD}/etc"
if [ ! -h "${HOME}" ]; then
  ln -sf ${VPATH} ${HOME}/
else
  ln -sf ${VPATH} ${LWD}/
fi
rm -rf "${LWD}/config" "${LWD}/playbooks"
ln -sf ${VPATH}/oooq/* "${LWD}/"

for p in $KNOWN_PATHS /var/tmp/reproduce; do
  [ "$p" = "${VPATH}/oooq" ] && continue
  echo "Chowning images cache and working dirs for ${p} (may take a while)..."
  sudo mkdir -p ${p} ||:
  sudo chown -R ${USER}:${USER} ${p} ||:
done

cd $HOME
. ${VPATH}/oooq/bin/activate

set +e
# Note we pick the hacked in paths in the custom ansible.cfg bind-mounted
if [ -z ${OOOQ_PATH} ]; then
  # Hack into oooq dev branch
  sudo pip install --upgrade git+https://github.com/${OOOQE_FORK}/tripleo-quickstart@${OOOQE_BRANCH}
  rsync -aLH /usr/config "${LWD}"
  rsync -aLH /usr/playbooks "${LWD}"
  rsync -aLH /usr/local/share/tripleo-quickstart/roles "${LWD}"
  rsync -aLH /usr/local/share/tripleo-quickstart/library "${LWD}"
  rsync -aLH /usr/local/share/tripleo-quickstart/test_plugins "${LWD}"
elif [ "$LWD" != "$OOOQ_WORKPATH" ]; then
  # Place the local git repo under the work path
  rsync -aLH $OOOQ_WORKPATH/config "${LWD}"
  rsync -aLH $OOOQ_WORKPATH/playbooks "${LWD}"
  rsync -aLH $OOOQ_WORKPATH/roles "${LWD}"
  rsync -aLH $OOOQ_WORKPATH/library "${LWD}"
  rsync -aLH $OOOQ_WORKPATH/test_plugins "${LWD}"
fi

if [ -z ${OOOQE_PATH} ]; then
  # Hack into oooq-extras dev branch
  sudo pip install --upgrade git+https://github.com/${OOOQE_FORK}/tripleo-quickstart-extras@${OOOQE_BRANCH}
  rsync -aLH /usr/config "${LWD}"
  rsync -aLH /usr/playbooks "${LWD}"
  rsync -aLH /usr/local/share/ansible/roles "${LWD}"
else
  # Place the local git repo under the work path
  rsync -aLH $OOOQE_WORKPATH/config "${LWD}"
  rsync -aLH $OOOQE_WORKPATH/playbooks "${LWD}"
  rsync -aLH $OOOQE_WORKPATH/roles "${LWD}"
fi
for p in $KNOWN_PATHS; do
  [ "$p" = "${VPATH}/oooq" -o "$p" = "$HOME" -a ! -h "$HOME" ] && continue
  sudo chown -R ${USER}:${USER} ${p} ||:
done

[ "${RELEASE:-}" ] && export IMAGECACHE="${IMAGECACHE}/${RELEASE}"

set +x
# Restore the saved state spread across LWD/WORKSPACE/IMAGECACHE dirs
# (ssh keys/setup, inventory, kernel images et al)
if [ "${TEARDOWN}" = "false" ]; then
  echo "Restoring state (syncing across known LWD/WORKSPACE/IMAGECACHE paths)"
  save-state.sh --sync
  sudo chmod a+r ${LWD}/vm_images/*
  sudo chown root:root ${LWD}/vm_images/*.qcow2
  cp -f "${LWD}/hosts" ${ANSIBLE_INVENTORY} 2>/dev/null
  eval $(ssh-agent)
else
  echo "Cleaning up state as TEARDOWN was requested"
  save-state.sh --purge
  rm -f "${LWD}"_deploy.log "${LWD}"_deploy_nice.log
  if [ "${IMAGECACHEBACKUP:-}" ]; then
    echo "Restoring all files from backup ${IMAGECACHEBACKUP} dir to ${IMAGECACHE}"
    mkdir -p ${IMAGECACHE}
    cp -af ${IMAGECACHEBACKUP}/* ${IMAGECACHE}/
  fi
  echo Pre-generate ssh keys for CI reproducer
  eval $(ssh-agent)
  ssh-keygen -b 2048 -t ed25519 -f ${HOME}/.ssh/id_ed25519 -N "" -q
  cp -f ${HOME}/.ssh/id_ed25519 ${HOME}/.ssh/id_ed25519.agent
  cp -f ${HOME}/.ssh/id_ed25519.pub ${HOME}/.ssh/id_ed25519.pub.agent
  chmod 0600 ${HOME}/.ssh/id_*
fi
ssh-add /var/tmp/.ssh/gerrit/id_ed25519
ssh-add ${HOME}/.ssh/id_ed25519.agent
ssh-add ${HOME}/.ssh/id_ed25519
sudo mkdir -p /root/.ssh
mkdir -p /var/tmp/reproduce/.ssh
sudo cp -f ${HOME}/.ssh/id* /root/.ssh
cp -f ${HOME}/.ssh/id* /var/tmp/reproduce/.ssh
mkdir -p ${LWD}/tripleo-ci-reproducer

cat >${HOME}/.vimrc<<EOF
set updatetime=100
set encoding=UTF-8
set expandtab
set shiftwidth=2
set tabstop=2
set softtabstop=2
set autoindent
set cindent
EOF

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
rm -f ${LWD}/etc
rm -f ${HOME}/etc
save-state.sh --sync 2>&1 > /dev/null

cd "${LWD}"
echo Note: ansible virthost is now localhost
echo Run a zuul libvirt reproducer script extracted from a tarball
echo with 'tripleo-reproducer.sh', or 'tripleo-reproducer-restore.sh'
echo ================================================================================================
echo Or use quickstart.sh wrapper
echo ================================================================================================
echo "Save deployed VMs state with 'save-state.sh' before exiting container"
echo "Destroy saved state with 'save-state.sh --purge' (but retain \$IMAGECACHEBACKUP contents)"
if [ "${UMOUNTS:-}" = "donkeys" ]; then
  su -p $USER
else
  /bin/bash
fi
