#!/bin/bash
# Wrap oooq with ansible
# requires ansible in the given venv or host
# must be executed from the oooq root dir
set -uxe

ARGS=${@:-" "}
USER=${USER:-bogdando}
SCRIPTS=/tmp/scripts
LOG_LEVEL=${LOG_LEVEL:--v}
ANSIBLE_TIMEOUT=${ANSIBLE_TIMEOUT:-900}
ANSIBLE_FORKS=${ANSIBLE_FORKS:-50}
TEARDOWN=${TEARDOWN:-true}
PLAY=${PLAY:-oooq-libvirt-provision.yaml}
WORKSPACE=${WORKSPACE:-/opt/oooq}
LWD=${LWD:-${HOME}/.quickstart}
CUSTOMVARS=${CUSTOMVARS:-custom.yaml}
LIBGUESTFS_BACKEND=${LIBGUESTFS_BACKEND:-direct}
SUPERMIN_KERNEL=${SUPERMIN_KERNEL:-}
SUPERMIN_MODULES=${SUPERMIN_MODULES:-}
SUPERMIN_KERNEL_VERSION=${SUPERMIN_KERNEL_VERSION:-}

function with_ansible {
  ansible-playbook \
    --become-user=root \
    --forks=$ANSIBLE_FORKS --timeout $ANSIBLE_TIMEOUT \
    -e teardown=$TEARDOWN \
    -e @${SCRIPTS}/${CUSTOMVARS} \
    ${ARGS} \
    $LOG_LEVEL $@ 2>&1 | tee -a _deploy.log
}

# A tricky sync for the state spread across LWD/WORKSPACE
function finalize {
  set +e
  for state in 'id_rsa_undercloud' 'id_rsa_virt_power' \
      'id_rsa_undercloud.pub' 'id_rsa_virt_power.pub' \
      'hosts' 'ssh.config.ansible' 'ssh.config.local.ansible' \
      'overcloud-full.vmlinuz' 'overcloud-full.initrd' \
      'latest-overcloud-full.tar' 'latest-ipa_images.tar'; do
    cp -uL "${WORKSPACE}/${state}" ${LWD}/ 2>/dev/null ||
    cp -uL "${LWD}/${state}" ${WORKSPACE}/ 2>/dev/null
  done
  chmod 600 ${LWD}/id_*
  chmod 600 ${WORKSPACE}/id_*
  cp -f ${WORKSPACE}/overcloud-full.{vmlinuz,initrd} ${LWD}/ 2>/dev/null
  # Those should survive teardown, if updated
  if [ "${IMAGECACHEBACKUP:-}" ]; then
    cp -uL ${IMAGECACHE}/latest-overcloud-full.tar ${IMAGECACHEBACKUP}/
    cp -uL ${IMAGECACHE}/latest-ipa_images.tar ${IMAGECACHEBACKUP}/
  fi
  set -e
}
trap finalize EXIT

sudo mkdir -p /etc/ansible

# autodetect plays
if [ -f ${SCRIPTS}/playbooks/${PLAY} ]; then
  PLAY="${SCRIPTS}/playbooks/${PLAY}"
else
  PLAY="playbooks/${PLAY}"
fi

if [[ "${TEARDOWN}" == "true" && "${PLAY}" =~ "oooq-libvirt-provision" ]]; then
  # provision VMs, generate inventory and exit
  # TODO traas provision to come here as well maybe
  inventory=${SCRIPTS}/inventory.ini
  with_ansible -u ${USER} -i ${inventory} ${PLAY}
  finalize
  sudo cp -f ${LWD}/hosts /etc/ansible/
  cp -f ${LWD}/hosts /tmp/oooq/
  echo "# Generated for quickstart VMs IPMI/VBMC, purge this later manually" >> \
  /tmp/authorized_keys
  cat ${LWD}/id_rsa_virt_power.pub  >> /tmp/authorized_keys
  cp -f /tmp/authorized_keys ${HOME}/.ssh/authorized_keys
else
  # switch to the generated inventory and deploy a PLAY, if already provisioned VMs
  inventory=${LWD}/hosts
  [ -f "${inventory}" ] || cp ${SCRIPTS}/inventory.ini ${LWD}/hosts
  sudo cp -f ${inventory} /etc/ansible/
  cp -f ${inventory} /tmp/oooq/

  echo "Check nodes connectivity"
  ansible -m ping all

  echo "Deploy with quickstart, use playbook ${PLAY}"
  with_ansible ${PLAY}
fi
