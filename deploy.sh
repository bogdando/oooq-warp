#!/bin/bash
# Wrap oooq with ansible
# requires ansible in the given venv or host
# must be executed from the oooq root dir
set -uxe

USER=${USER:-bogdando}
SCRIPTS=/tmp/scripts
LOG_LEVEL=${LOG_LEVEL:--v}
ANSIBLE_TIMEOUT=${ANSIBLE_TIMEOUT:-900}
ANSIBLE_FORKS=${ANSIBLE_FORKS:-50}
TEARDOWN=${TEARDOWN:-true}
PLAY=${PLAY:-oooq-libvirt-provision.yaml}
WORKSPACE=${WORKSPACE:-/opt/oooq}
LWD=${LWD:-${HOME}/.quickstart}
INTERACTIVE=${INTERACTIVE:-true}

function snap {
  set +e
  sudo virsh suspend $1
  sudo virsh snapshot-delete $1  $2
  sudo virsh snapshot-create-as --name=$2 $1 || sudo virsh snapshot $1
  sync
  sudo virsh resume $1
  set -e
}

function with_ansible {
  ansible-playbook \
    --become-user=root \
    --forks=$ANSIBLE_FORKS --timeout $ANSIBLE_TIMEOUT \
    -e teardown=$TEARDOWN \
    -e @${SCRIPTS}/custom.yaml \
    $LOG_LEVEL $@
}

function finalize {
  sudo cp -af ${LWD}/* ${WORKSPACE}/
}
trap finalize EXIT

if [ "${TEARDOWN}" != "false" -a "${PLAY}" = "oooq-libvirt-provision.yaml" ]; then
  # provision VMs, generate inventory, exit if INTERACTIVE mode
  # TODO traas provision to come here as well
  inventory=${SCRIPTS}/inventory.ini
  with_ansible -u ${USER} -i ${inventory} ${SCRIPTS}/oooq-libvirt-provision.yaml
  [ "$INTERACTIVE" = "true" ] && exit 0
fi

# switch to the generated inventory
inventory=${LWD}/hosts
[ -f "${inventory}" ] || cp ${SCRIPTS}/inventory.ini ${LWD}/hosts

echo "Check nodes connectivity"
ansible -i ${inventory} -m ping all

echo "Deploy with quickstart, use playbook ${PLAY}"
with_ansible -i ${inventory} ${SCRIPTS}/${PLAY}
