#!/bin/bash
# Wrap OS of the given active user with the centos7 box and oooq
set -uxe

DEV=${DEV:-/dev/sda}
IOPSW=${IOPSW:-0}
IOPSR=${IOPSR:-0}
IOW=${IOW:-0}
IOR=${IOR:-0}
CPU=${CPU:-0}
MEM=${MEM:-0}

# defaults
TERMOPTS=${TERMOPTS:--it}
TEARDOWN=${TEARDOWN:-true}
USER=${USER:-bogdando}
OOOQE_BRANCH=${OOOQE_BRANCH:-master}
OOOQE_FORK=${OOOQE_FORK:-openstack}
OOOQE_PATH=${OOOQE_PATH:-}
OOOQ_BRANCH=${OOOQ_BRANCH:-master}
OOOQ_FORK=${OOOQ_FORK:-openstack}
OOOQ_PATH=${OOOQ_PATH:-}
VPATH=${VPATH:-/home/${USER}/Envs}
WORKSPACE=${WORKSPACE:-/tmp/qs}
LWD=${LWD:-/home/${USER}/.quickstart}
PLAY=${PLAY:-oooq-libvirt-provision.yaml}
CONTROLLER_HOSTS=${CONTROLLER_HOSTS:-""}
COMPUTE_HOSTS=${COMPUTE_HOSTS:-""}
SUBNODES_SSH_KEY=${SUBNODES_SSH_KEY:-~/.ssh/id_rsa}
CUSTOMVARS=${CUSTOMVARS:-custom.yaml}
LIBGUESTFS_BACKEND=${LIBGUESTFS_BACKEND:-direct}

if [ "${OOOQE_PATH}" ]; then
  MOUNT_EXTRAS="-v ${OOOQE_PATH}:/tmp/oooq-extras"
  OOOQE_PATH=/tmp/oooq-extras
fi
if [ "${OOOQ_PATH}" ]; then
  MOUNT_QUICKSTART="-v ${OOOQ_PATH}:/tmp/oooq"
  OOOQ_PATH=/tmp/oooq
fi
if [ "${IMAGECACHEBACKUP:-}" ]; then
  MOUNT_IMAGECACHEBACKUP="-v ${IMAGECACHEBACKUP}:${IMAGECACHEBACKUP}:ro"
fi

docker run ${TERMOPTS} --rm --privileged \
  --device-read-bps=${DEV}:${IOR} \
  --device-write-bps=${DEV}:${IOW} \
  --device-read-iops=${DEV}:${IOPSR} \
  --device-write-iops=${DEV}:${IOPSW} \
  --cpus=4 --cpu-shares=${CPU} \
  --memory-swappiness=0 --memory=${MEM} \
  --net=host --pid=host --uts=host --ipc=host \
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
  -e VIRTUALENVWRAPPER_PYTHON=/usr/bin/python \
  -e OOOQE_BRANCH=${OOOQE_BRANCH} \
  -e OOOQE_FORK=${OOOQE_FORK} \
  -e CONTROLLER_HOSTS=${CONTROLLER_HOSTS} \
  -e COMPUTE_HOSTS=${COMPUTE_HOSTS} \
  -e SUBNODES_SSH_KEY=${SUBNODES_SSH_KEY} \
  -e CUSTOMVARS=${CUSTOMVARS} \
  -e LIBGUESTFS_BACKEND=${LIBGUESTFS_BACKEND} \
  -e SUPERMIN_KERNEL=${SUPERMIN_KERNEL:-} \
  -e SUPERMIN_MODULES=${SUPERMIN_MODULES:-} \
  -e SUPERMIN_KERNEL_VERSION=${SUPERMIN_KERNEL_VERSION:-} \
  -e OOOQ_DIR=/tmp/oooq \
  -e OPT_WORKDIR=/tmp/oooq \
  -e HOST_BREXT_IP=${HOST_BREXT_IP:-} \
  -e TERMOPTS=${TERMOPTS} \
  -v /opt/vm_images/:/opt/vm_images/ \
  -v /var/lib/libvirt:/var/lib/libvirt \
  -v /run/libvirt:/run/libvirt \
  -v /etc/libvirt/libvirtd.conf:/etc/libvirt/libvirtd.conf:ro \
  -v /dev:/dev \
  -v /sys/fs/cgroup:/sys/fs/cgroup \
  -v /lib/modules:/lib/modules:ro \
  -v ${IMAGECACHE}:${IMAGECACHE} \
  ${MOUNT_QUICKSTART:-} \
  ${MOUNT_EXTRAS:-} \
  ${MOUNT_IMAGECACHEBACKUP:-} \
  -v $(pwd)/ansible.cfg:/tmp/oooq/ansible.cfg:ro \
  -v $(pwd)/entry.sh:/usr/local/sbin/entry.sh:ro \
  -v ${WORKSPACE}:${WORKSPACE} \
  -v ${LWD}:$LWD \
  -v /home/${USER}/.ssh/authorized_keys:/tmp/.ssh/authorized_keys \
  -v $(pwd):/tmp/scripts:ro \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -v /boot:/boot:ro \
  -u $(id -u $USER):$(id -g $USER) --group-add $(cut -d: -f3 <(getent group libvirt)) \
  --entrypoint /usr/local/sbin/entry.sh \
  --name runner bogdando/oooq-runner:0.1 \
  ${@:-}
