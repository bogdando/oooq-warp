#!/bin/bash
# Wrap OS of the given active user with the centos7 box and oooq
set -uxe

DEV=${DEV:-/dev/sda}
IOPSW=${IOPSW:-60}
IOPSR=${IOPSR:-60}
IOW=${IOW:-35mb}
IOR=${IOR:-60mb}
CPU=${CPU:-800}
MEM=${MEM:-7G}

# defaults
INTERACTIVE=${INTERACTIVE:-true}
TEARDOWN=${TEARDOWN:-true}
USER=${USER:-bogdando}
OOOQE_BRANCH=${OOOQE_BRANCH:-master}
OOOQE_FORK=${OOOQE_FORK:-openstack}
OOOQE_PATH=${OOOQE_PATH:-}
OOOQ_BRANCH=${OOOQ_BRANCH:-master}
OOOQ_FORK=${OOOQ_FORK:-openstack}
OOOQ_PATH=${OOOQ_PATH:-}
VPATH=${VPATH:-/root/Envs}
WORKSPACE=${WORKSPACE:-/tmp/qs}
LWD=${LWD:-/home/${USER}/.quickstart}
PLAY=${PLAY:-oooq-libvirt-provision.yaml}
CONTROLLER_HOSTS=${CONTROLLER_HOSTS:-""}
COMPUTE_HOSTS=${COMPUTE_HOSTS:-""}
SUBNODES_SSH_KEY=${SUBNODES_SSH_KEY:-~/.ssh/id_rsa}
HACK=${HACK:-false}
CUSTOMVARS=${CUSTOMVARS:-custom.yaml}

if [ "${OOOQE_PATH}" ]; then
  MOUNT_EXTRAS="-v ${OOOQE_PATH}:/tmp/oooq-extras"
  OOOQE_PATH=/tmp/oooq-extras
fi
if [ "${OOOQ_PATH}" ]; then
  MOUNT_QUICKSTART="-v ${OOOQ_PATH}:/tmp/oooq"
  OOOQ_PATH=/tmp/oooq
fi

docker run -it --rm --privileged \
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
  -e OOOQ_PATH=${OOOQ_PATH:-} \
  -e OOOQE_PATH=${OOOQE_PATH:-} \
  -e VPATH=${VPATH} \
  -e HOME=/home/${USER} \
  -e TEARDOWN=${TEARDOWN} \
  -e VIRTUALENVWRAPPER_PYTHON=/usr/bin/python \
  -e OOOQE_BRANCH=${OOOQE_BRANCH} \
  -e OOOQE_FORK=${OOOQE_FORK} \
  -e INTERACTIVE=${INTERACTIVE} \
  -e CONTROLLER_HOSTS=${CONTROLLER_HOSTS} \
  -e COMPUTE_HOSTS=${COMPUTE_HOSTS} \
  -e SUBNODES_SSH_KEY=${SUBNODES_SSH_KEY} \
  -e HACK=${HACK} \
  -e CUSTOMVARS=${CUSTOMVARS} \
  -v /var/lib/libvirt:/var/lib/libvirt \
  -v /run/libvirt:/run/libvirt \
  -v /dev:/dev:ro \
  -v /lib/modules:/lib/modules:ro \
  -v ${WORKSPACE}:${WORKSPACE} \
  -v ${IMAGECACHE}:${IMAGECACHE} \
  ${MOUNT_QUICKSTART:-} \
  ${MOUNT_EXTRAS:-} \
  -v $(pwd)/ansible.cfg:/tmp/oooq/ansible.cfg:ro \
  -v ${LWD}:$LWD \
  -v $(pwd):/tmp/scripts:ro \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -u 1000 \
  --entrypoint /bin/bash \
  --name runner bogdando/oooq-runner:0.1 \
  -c "sudo cp /tmp/scripts/*.sh /usr/local/sbin/ && \
      sudo chmod +x /usr/local/sbin/* && entry.sh"
