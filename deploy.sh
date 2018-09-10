#!/bin/bash
# Wrap oooq with ansible
# requires ansible in the given venv or host
# must be executed from the oooq root dir
set -uxe
if [ -t 1 ] ; then
  export ANSIBLE_FORCE_COLOR=true
else
  export ANSIBLE_FORCE_COLOR=false
fi
export ANSIBLE_STDOUT_CALLBACK=debug
echo "## Storing outputs to ./_deploy.log"
echo "$0 $@" > _deploy.log
exec &> >(tee -i -a _deploy.log)

LANG=C
ARGS=${@:-}
RC=1
function with_ansible {
  ansible-playbook \
    --become-user=root \
    --forks=$ANSIBLE_FORKS --timeout $ANSIBLE_TIMEOUT \
    -e teardown=$TEARDOWN \
    -e @${SCRIPTS_WORKPATH}/${CUSTOMVARS} \
    ${ARGS} \
    $LOG_LEVEL $@ 2>&1
  RC=$?
}

# A tricky sync for the state spread across LWD/WORKSPACE
function finalize {
  set +e
  save-state.sh --sync
  set -e
  # results|message|msg|get_xml|std\w+ get line-wrapped nicely
  # item|cmd|end|start|failed|rc|delta left intact but its own quotes stripped off
  cat _deploy.log |\
  sed -r 's/"\S+":\s(""|\[\]|\{\})(,\s)?//g; s/\\n/\n/g; s/\\t/\t/g; s/",\s"/",\n"/g' >\
    _deploy_nice.log
}
trap finalize INT EXIT

sudo mkdir -p /etc/ansible

# autodetect plays
if [ -f ${SCRIPTS_WORKPATH}/playbooks/${PLAY} ]; then
  PLAY="${SCRIPTS_WORKPATH}/playbooks/${PLAY}"
else
  PLAY="playbooks/${PLAY}"
fi

if [[ "${TEARDOWN}" == "true" && "${PLAY}" =~ "oooq-libvirt-provision" ]]; then
  # provision VMs, generate inventory and exit
  # TODO traas provision to come here as well maybe
  inventory=${SCRIPTS_WORKPATH}/inventory.ini
  with_ansible -u ${USER} -i ${inventory} ${PLAY}
  finalize
  trap - INT EXIT
  sudo cp -f ${LWD}/hosts /etc/ansible/ 2>/dev/null
else
  # switch to the generated inventory and deploy a PLAY, if already provisioned VMs
  inventory=${LWD}/hosts
  [ -f "${inventory}" ] || cp ${SCRIPTS_WORKPATH}/inventory.ini ${LWD}/hosts
  sudo cp -f ${inventory} /etc/ansible/ 2>/dev/null

  echo "Check nodes connectivity"
  ansible -m ping all

  echo "Deploy with quickstart, use playbook ${PLAY}"
  with_ansible ${PLAY}
fi
