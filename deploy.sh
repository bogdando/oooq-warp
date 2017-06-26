#!/bin/bash
# Wrap oooq with ansible
# requires ansible in the given venv or host
# must be executed from the oooq root dir
set -uxe

USER=${USER:-bogdando}
SCRIPTS=/tmp/scripts
LOG_LEVEL=${LOG_LEVEL:--v}
ANSIBLE_TIMEOUT=${ANSIBLE_TIMEOUT:-900}
ANSIBLE_FORKS=${ANSIBLE_FORKS:-10}
TEARDOWN=${TEARDOWN:-true}
PLAY=${PLAY:-oooq-warp.yaml}
WORKSPACE=${WORKSPACE:-/opt/oooq}
LWD=${LWD:-${HOME}/.quickstart}
MAKE_SNAPSHOTS=${MAKE_SNAPSHOTS:-true}
QUICKSTARTISH=${QUICKSTARTISH:-false}

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

function with_quickstart {
  # TODO --nodes --config --release
  echo pip > /tmp/foo
  cd ${WORKSPACE}
  cp -f $1 ${WORKSPACE}/
  ./quckstart.sh \
    --requirements /tmp/foo \
    --no-clone \
    --retain-inventory \
    --teardown $TEARDOWN \
    --system-site-packages \
    --working-dir ${LWD} \
    --playbook ${WORKSPACE}/${1##*/}
    -e teardown=$TEARDOWN \
    -e @${SCRIPTS}/custom.yaml \
    $LOG_LEVEL 127.0.0.2
  cd -
}

function with_undercloud_root {
  ssh -F ${LWD}/ssh.config.local.ansible undercloud-root $@
}

# persist generated things on exit
function finalize {
  sudo cp -af ${LWD}/* ${WORKSPACE}/
}

echo "Checking inventory nodes"
ansible -i ${SCRIPTS}/inventory.ini -m ping all
echo "Deploying with oooq"
inventory=${SCRIPTS}/inventory.ini

trap finalize EXIT

# provision VMs, generate inventory by localhost virthost ansible node
if [ "${TEARDOWN}" != "false" -a "${TEARDOWN}" != "none" \
     -a "${PLAY}" = "oooq-warp.yaml" ]; then

  echo "Trying to ensure bridge-nf-call-iptables is disabled..."
  br_netfilter=$(cat /proc/sys/net/bridge/bridge-nf-call-iptables)
  if [ "$br_netfilter" = "1" ]; then
    sudo sh -c 'echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables'
  fi

  if [ "$QUICKSTARTISH" = "true" ]; then
    with_quickstart ${SCRIPTS}/oooq-warp.yaml
  else
    with_ansible -u ${USER} -i ${inventory} ${SCRIPTS}/oooq-warp.yaml
  fi

  [ "${MAKE_SNAPSHOTS}" = "true" ] && snap undercloud ready
  exit 0
fi

# switch to the generated inventory, if any
inventory=${LWD}/hosts
[ -f "${inventory}" ] || cp ${SCRIPTS}/inventory.ini ${LWD}/hosts

# Check undercloud node connectivity and deploy
ansible -i ${inventory} -m ping all
if [ "${PLAY}" = "oooq-under.yaml" ]; then
  # local deployments
  # FIXME:tail logs from the undercloud VM as install.sh hides them
  ssh -F ${LWD}/ssh.config.local.ansible undercloud touch /home/stack/undercloud_install.log
  ssh -F ${LWD}/ssh.config.local.ansible undercloud tail -fn1 /home/stack/undercloud_install.log&
  if [ "$QUICKSTARTISH" = "true" ]; then
    with_quickstart ${SCRIPTS}/oooq-under.yaml
  else
    with_ansible -i ${inventory} ${SCRIPTS}/oooq-under.yaml
  fi
  [ "${MAKE_SNAPSHOTS}" = "true" ] && snap undercloud deployed
else
  # custom/non-local cases
  if [ "$QUICKSTARTISH" = "true" ]; then
    with_quickstart ${SCRIPTS}/${PLAY}
  else
    with_ansible -i ${inventory} ${SCRIPTS}/${PLAY}
  fi
fi
