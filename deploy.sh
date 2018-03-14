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

function finalize {
  sudo cp -af ${LWD}/* ${WORKSPACE}/
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
  sudo cp -f ${LWD}/hosts /etc/ansible/
  sudo cp -f ${LWD}/hosts /tmp/oooq/
else
  # switch to the generated inventory and deploy a PLAY, if already provisioned VMs
  inventory=${LWD}/hosts
  [ -f "${inventory}" ] || cp ${SCRIPTS}/inventory.ini ${LWD}/hosts
  sudo cp -f ${inventory} /etc/ansible/
  sudo cp -f ${inventory} /tmp/oooq/

  echo "Check nodes connectivity"
  ansible -m ping all

  echo "Deploy with quickstart, use playbook ${PLAY}"
  with_ansible ${PLAY}
fi
