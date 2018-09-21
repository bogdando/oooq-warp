#!/bin/bash
# Wrap OS of the given active user with the centos7 box and oooq
set -uxe

# Internal env vars, only used to run a container wrapper
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
LIBGUESTFS_BACKEND_SETTINGS=${LIBGUESTFS_BACKEND_SETTINGS:-force_tcg}
SUBNODES_SSH_KEY=${SUBNODES_SSH_KEY:-~/.ssh/id_rsa}
# Known work paths inside of the container
OOOQ_WORKPATH=/var/tmp/oooq
OOOQE_WORKPATH=/var/tmp/oooq-extras
SCRIPTS_WORKPATH=/var/tmp/scripts
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

# FIXME: UC cannot differentiate nor take non existing working_dir in quickstart.
# We have to use the common path /tmp for wirthost and UC because of that
# unfortunate reason. If/once fixed, make working_dir like /tmp/.quickstart at
# virthost, and whatever else non-ephemeral for undercloud VM. Until then,
# UC may not survive the VM reboot nicely (all artifacts produced by quickstart
# will be gone)
if [ "${RAMFS}" = "true" ]; then
  echo "Using /tmp for images cache and working dir, all stored in RAM."
  echo "WARNING: With RAMFS=true, it may eat a lot of memory, USE WITH CAUTION!"
  echo
  echo "If you want an environment persisted after the container exited/node rebooted,"
  echo "use an existing (non /tmp) host path for LWD."
  echo "And remember to save-state.sh manually by the real host path LWD."
  echo "The saved state will be auto-picked up by the entry point, when starting new container."
  echo "WARNING: UC cannot persist its /tmp working dir though. So do not reboot it"
  echo "but suspend/resume/snapshot/revert VM instead!"
  echo
  IMAGECACHE=/var/cache/tripleo-quickstart/images
  WORKSPACE=/tmp
  MOUNT_IMAGECACHE="-v /tmp:${IMAGECACHE}"
elif [ "${IMAGECACHE:-}" -a -d "${IMAGECACHE:-/tmp}" -a "${IMAGECACHE:-}" != "/home/$USER" ]; then
  MOUNT_IMAGECACHE="-v ${IMAGECACHE}:/var/cache/tripleo-quickstart/images"
else
  echo "Not bind-mounting IMAGECACHE ${IMAGECACHE:-}"
  echo "NOTE: it cannot take the current user's \$HOME path"
  IMAGECACHE=/var/cache/tripleo-quickstart/images
  echo "Using ephemeral IMAGECACHE ${IMAGECACHE} instead"
  echo
fi

if [ "${LWD:-}" -a -d "${LWD:-/tmp}" -a "${LWD:-}" != "/home/$USER" -a "${LWD:-}" != "$IMAGECACHE" ]; then
  MOUNT_LWD="-v ${LWD}:${LWD}"
else
  echo "Not bind-mounting local working dir LWD ${LWD:-}"
  echo "NOTE: it cannot take the current user's \$HOME path or share IMAGECACHE dir"
  LWD=/home/$USER
  echo "Using ephemeral LWD ${LWD} instead"
  echo
fi

if [ "${WORKSPACE:-}" -a -d "${WORKSPACE:-/tmp}" -a "${WORKSPACE:-}" != "/home/$USER" -a "${WORKSPACE:-}" != "$IMAGECACHE" ]; then
  MOUNT_WORKSPACE="-v ${WORKSPACE}:${WORKSPACE}"
else
  echo "Not bind-mounting working dir WORKSPACE ${WORKSPACE:-}"
  echo "NOTE: it cannot take the current user's \$HOME path or share IMAGECACHE dir"
  WORKSPACE=/home/$USER
  echo "Using ephemeral WORKSPACE $WORKSPACE instead"
  echo
fi

if [ "$RAMFS" != "false" ]; then
  KNOWN_PATHS=$(printf %"b\n" "${LWD}\n${WORKSPACE}"|sort -u)
else
  KNOWN_PATHS=$(printf %"b\n" "${LWD}\n${WORKSPACE}\n${IMAGECACHE}"|sort -u)
fi
set -x

docker run ${TERMOPTS} --rm --privileged \
  --cpus=1 --cpu-shares=${CPU} \
  --memory-swappiness=0 --memory=${MEM} \
  --net=host --pid=host --uts=host --ipc=host \
  -e RAMFS=${RAMFS} \
  -e PATH="${OOOQ_WORKPATH}:${LWD}:${PATH}" \
  -e KNOWN_PATHS="${KNOWN_PATHS}" \
  -e USER=${USER} \
  -e PLAY=${PLAY} \
  -e WORKSPACE=${WORKSPACE} \
  -e OPT_WORKDIR=${LWD} \
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
  -e LIBGUESTFS_BACKEND_SETTINGS=${LIBGUESTFS_BACKEND_SETTINGS} \
  -e SUPERMIN_KERNEL=${SUPERMIN_KERNEL:-} \
  -e SUPERMIN_MODULES=${SUPERMIN_MODULES:-} \
  -e SUPERMIN_KERNEL_VERSION=${SUPERMIN_KERNEL_VERSION:-} \
  -e HOST_BREXT_IP=${HOST_BREXT_IP:-} \
  -e TERMOPTS=${TERMOPTS} \
  -e SCRIPTS_WORKPATH=${SCRIPTS_WORKPATH} \
  -e OOOQ_WORKPATH=${OOOQ_WORKPATH} \
  -e OOOQE_WORKPATH=${OOOQE_WORKPATH} \
  -e LOG_LEVEL=${LOG_LEVEL:--v} \
  -e ANSIBLE_TIMEOUT=${ANSIBLE_TIMEOUT:-900} \
  -e ANSIBLE_FORKS=${ANSIBLE_FORKS:-20} \
  -e ANSIBLE_STDOUT_CALLBACK=${ANSIBLE_STDOUT_CALLBACK:-debug} \
  -e ANSIBLE_PYTHON_INTERPRETER=/home/${USER}/Envs/oooq/bin/python \
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
  -v ${PWD}/ansible.cfg:${OOOQ_WORKPATH}/ansible.cfg:ro \
  -v ${PWD}/entry.sh:/usr/local/sbin/entry.sh:ro \
  -v ${PWD}/save-state.sh:/usr/local/sbin/save-state.sh:ro \
  -v /home/${USER}/.ssh/authorized_keys:/var/tmp/.ssh/authorized_keys \
  -v ${PWD}:${SCRIPTS_WORKPATH}:ro \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -v /etc/sudoers:/etc/sudoers:ro \
  -v /boot:/boot:ro \
  -u ${uid}:${gid} --group-add ${host_libvirt_gid} \
  --entrypoint /usr/local/sbin/entry.sh \
  --name runner bogdando/oooq-runner:0.2 \
  ${@:-}
