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
INTERACTIVE=${INTERACTIVE:-true}
HACK=${HACK:-false}

function with_ansible {
  ansible-playbook \
    --become-user=root \
    --forks=$ANSIBLE_FORKS --timeout $ANSIBLE_TIMEOUT \
    -e teardown=$TEARDOWN \
    -e @${SCRIPTS}/custom.yaml \
    ${ARGS} \
    $LOG_LEVEL $@
}

function finalize {
  sudo cp -af ${LWD}/* ${WORKSPACE}/
}
trap finalize EXIT

if [ "${TEARDOWN}" = "true" -a "${PLAY}" = "oooq-libvirt-provision.yaml" ]; then
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

if [ "$HACK" = "false" ]; then
  echo "Deploy with quickstart, use playbook ${PLAY}"
  with_ansible -i ${inventory} ${SCRIPTS}/playbooks/${PLAY}
else
  # hacking/racy mode for scripted ansible-playbook calls interleaved by tags:
  echo "Deploy with quickstart, interleaved hacking (experimental)"
  with_ansible -i ${inventory} ${SCRIPTS}/playbooks/hack_step_repos.yml
  (while true; do with_ansible -i ${inventory} ${SCRIPTS}/playbooks/hack_step_prep.yml; [ $? -eq 0 ] && break; sleep 20; done)&
  with_ansible -i ${inventory} ${SCRIPTS}/playbooks/hack_step_uc.yml --skip-tags overcloud-prep-containers
  with_ansible -i ${inventory} ${SCRIPTS}/playbooks/hack_step_oc.yml
fi
