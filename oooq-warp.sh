#!/bin/bash
# Wrap OS of the given active user with the centos7 box and oooq
set -uxe

# Internal env vars, only used to run a container wrapper
DEV=${DEV:-/dev/sda}
IOPSW=${IOPSW:-0}
IOPSR=${IOPSR:-0}
IOW=${IOW:-0}
IOR=${IOR:-0}
CPU=${CPU:-0}
MEM=${MEM:-0}

# Defines global env defaults in the wrapper container
RAMFS=${RAMFS:-false}
TERMOPTS=${TERMOPTS:--it}
TEARDOWN=${TEARDOWN:-true}
# non_root_user et al
USER=${USER:-bogdando}
# Known paths to bind-mount git repos (to clone or pick up from a local path)
OOOQE_BRANCH=${OOOQE_BRANCH:-master}
OOOQE_FORK=${OOOQE_FORK:-openstack}
OOOQ_BRANCH=${OOOQ_BRANCH:-master}
OOOQ_FORK=${OOOQ_FORK:-openstack}
# oooq venv pre-created in the container
VPATH=${VPATH:-/home/${USER}/Envs}
PLAY=${PLAY:-oooq-libvirt-provision.yaml}
CUSTOMVARS=${CUSTOMVARS:-custom.yaml}
LIBGUESTFS_BACKEND=${LIBGUESTFS_BACKEND:-direct}
SUBNODES_SSH_KEY=${SUBNODES_SSH_KEY:-~/.ssh/id_rsa}
# Known work paths inside of the container
OOOQ_WORKPATH=/tmp/oooq
OOOQE_WORKPATH=/tmp/oooq-extras
SCRIPTS_WORKPATH=/tmp/scripts
USE_QUICKSTART_WRAP=false

set +x
uid=$(id -u $USER)
gid=$(id -g $USER)
host_libvirt_gid=$(cut -d: -f3 <(getent group libvirt))

if [ "${OOOQE_PATH:-}" -a -d "${OOOQE_PATH:-/tmp}" ]; then
  MOUNT_EXTRAS="-v ${OOOQE_PATH}:${OOOQE_WORKPATH}"
  OOOQE_PATH=$OOOQE_WORKPATH
fi

if [ "${OOOQ_PATH:-}" -a -d "${OOOQ_PATH:-/tmp}" ]; then
  MOUNT_QUICKSTART="-v ${OOOQ_PATH}:${OOOQ_WORKPATH}"
  OOOQ_PATH=$OOOQ_WORKPATH
fi

if [ "${IMAGECACHEBACKUP:-}" -a -d "${IMAGECACHEBACKUP:-/tmp}" ]; then
  MOUNT_IMAGECACHEBACKUP="-v ${IMAGECACHEBACKUP}:${IMAGECACHEBACKUP}:ro"
fi

if [ "${RAMFS}" = "true" ]; then
  echo "Using ephemeral /tmp/qs for images cache stored in RAM."
  echo "WARNING: With RAMFS=true, it may eat a lot of memory, USE WITH CAUTION!"
  echo
  echo "If you want an environment persisted after the container exited/node rebooted,"
  echo "use an existing (non /tmp) host path for at least WORKSPACE or LWD."
  echo "and save the env state by either of those real host paths."
  echo "The saved state will be auto-picked up by the entry point, when starting new container."
  echo
  IMAGECACHE=/var/cache/tripleo-quickstart/images
  MOUNT_IMAGECACHE="-v /tmp/qs:${IMAGECACHE}"
elif [ "${IMAGECACHE:-}" -a -d "${IMAGECACHE:-/tmp}" -a "${IMAGECACHE:-}" != "/home/$USER" ]; then
  MOUNT_IMAGECACHE="-v ${IMAGECACHE}:/var/cache/tripleo-quickstart/images"
else
  echo "Not bind-mounting IMAGECACHE ${IMAGECACHE:-}"
  echo "NOTE: it cannot take the current user's \$HOME path"
  IMAGECACHE=/home/$USER
  echo "Using ephemeral IMAGECACHE ${IMAGECACHE} instead"
  echo
fi

if [ "${LWD:-}" -a -d "${LWD:-/tmp}" -a "${LWD:-}" != "/home/$USER" ]; then
  MOUNT_LWD="-v ${LWD}:${LWD}"
else
  echo "Not bind-mounting local working dir LWD ${LWD:-}"
  echo "NOTE: it cannot take the current user's \$HOME path"
  LWD=/home/$USER
  echo "Using ephemeral LWD ${LWD} instead"
  echo
fi

if [ "${WORKSPACE:-}" -a -d "${WORKSPACE:-/tmp}" -a "${WORKSPACE:-}" != "/home/$USER" ]; then
  MOUNT_WORKSPACE="-v ${WORKSPACE}:${WORKSPACE}"
else
  echo "Not bind-mounting working dir WORKSPACE ${WORKSPACE:-}"
  echo "NOTE: it cannot take the current user's \$HOME path"
  WORKSPACE=/home/$USER
  echo "Using ephemeral WORKSPACE $WORKSPACE instead"
  echo
fi

if [ "${MOUNT_IMAGECACHE:-}${MOUNT_LWD:-}${MOUNT_WORKSPACE:-}" = "-v /tmp/qs:/var/tmp" ]; then
  echo "WARNING: Provisioned libvirt VMs may fail to start, if the node rebooted!"
  echo "If you want BMs persistent across reboots, specify at least any of WORKSPACE/LWD"
  echo "as existing host path or set RAMFS=false."
  echo
fi

# FIXME: May be I can always use the first case?
if [ "${LWD:-}" = "/home/$USER" ]; then
  dest=$LWD
else
  dest=$OOOQ_WORKPATH
fi
set -x

docker run ${TERMOPTS} --rm --privileged \
  --device-read-bps=${DEV}:${IOR} \
  --device-write-bps=${DEV}:${IOW} \
  --device-read-iops=${DEV}:${IOPSR} \
  --device-write-iops=${DEV}:${IOPSW} \
  --cpus=4 --cpu-shares=${CPU} \
  --memory-swappiness=0 --memory=${MEM} \
  --net=host --pid=host --uts=host --ipc=host \
  -e PATH="${OOOQ_WORKPATH}:${LWD}:${PATH}" \
  -e USER=${USER} \
  -e PLAY=${PLAY} \
  -e WORKSPACE=${WORKSPACE} \
  -e LWD=${LWD} \
  -e IMAGECACHE=${IMAGECACHE} \
  -e IMAGECACHEBACKUP=${IMAGECACHEBACKUP:-} \
  -e OOOQ_PATH=${OOOQ_PATH:-} \
  -e OOOQE_PATH=${OOOQE_PATH:-} \
  -e VPATH=${VPATH} \
  -e HOME=/home/${USER} \
  -e TEARDOWN=${TEARDOWN} \
  -e OOOQE_BRANCH=${OOOQE_BRANCH} \
  -e OOOQE_FORK=${OOOQE_FORK} \
  -e CONTROLLER_HOSTS=${CONTROLLER_HOSTS:-} \
  -e COMPUTE_HOSTS=${COMPUTE_HOSTS:-} \
  -e SUBNODES_SSH_KEY=${SUBNODES_SSH_KEY} \
  -e CUSTOMVARS=${CUSTOMVARS} \
  -e LIBGUESTFS_BACKEND=${LIBGUESTFS_BACKEND} \
  -e SUPERMIN_KERNEL=${SUPERMIN_KERNEL:-} \
  -e SUPERMIN_MODULES=${SUPERMIN_MODULES:-} \
  -e SUPERMIN_KERNEL_VERSION=${SUPERMIN_KERNEL_VERSION:-} \
  -e dest=${dest} \
  -e HOST_BREXT_IP=${HOST_BREXT_IP:-} \
  -e TERMOPTS=${TERMOPTS} \
  -e SCRIPTS_WORKPATH=${SCRIPTS_WORKPATH} \
  -e OOOQ_WORKPATH=${OOOQ_WORKPATH} \
  -e OOOQE_WORKPATH=${OOOQE_WORKPATH} \
  -e LOG_LEVEL=${LOG_LEVEL:--v} \
  -e ANSIBLE_TIMEOUT=${ANSIBLE_TIMEOUT:-900} \
  -e ANSIBLE_FORKS=${ANSIBLE_FORKS:-20} \
  -e USE_QUICKSTART_WRAP=${USE_QUICKSTART_WRAP} \
  -v /var/lib/libvirt:/var/lib/libvirt \
  -v /run/libvirt:/run/libvirt \
  -v /etc/libvirt/libvirtd.conf:/etc/libvirt/libvirtd.conf:ro \
  -v /dev:/dev \
  -v /sys/fs/cgroup:/sys/fs/cgroup \
  -v /lib/modules:/lib/modules:ro \
  ${MOUNT_IMAGECACHE:-} \
  ${MOUNT_QUICKSTART:-} \
  ${MOUNT_EXTRAS:-} \
  ${MOUNT_IMAGECACHEBACKUP:-} \
  ${MOUNT_WORKSPACE:-} \
  ${MOUNT_LWD:-} \
  -v ${PWD}/ansible.cfg:${dest}/ansible.cfg \
  -v ${PWD}/entry.sh:/usr/local/sbin/entry.sh \
  -v ${PWD}/save-state.sh:/usr/local/sbin/save-state.sh \
  -v /home/${USER}/.ssh/authorized_keys:/tmp/.ssh/authorized_keys \
  -v ${PWD}:${SCRIPTS_WORKPATH} \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -v /boot:/boot:ro \
  -u ${uid}:${gid} --group-add ${host_libvirt_gid} \
  --entrypoint /usr/local/sbin/entry.sh \
  --name runner bogdando/oooq-runner:0.1 \
  ${@:-}
