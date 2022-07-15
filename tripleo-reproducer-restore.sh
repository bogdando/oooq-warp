#!/bin/bash
sudo chmod -R a+rwt ${LWD}/logs
cp -f "${LWD}/hosts" "${LWD}/tripleo-ci-reproducer/"
mkdir -p "${LWD}/etc/pki/tls/certs/"
cp -f "${LWD}/ca-bundle.crt" "${LWD}/etc/pki/tls/certs/"

mkdir -p /var/tmp/reproduce/roles/ /var/tmp/reproduce/playbooks

git -C /var/tmp/reproduce/git/tripleo-quickstart pull ||\
  git clone -b dev https://github.com/bogdando/tripleo-quickstart \
    /var/tmp/reproduce/git/tripleo-quickstart
git -C /var/tmp/reproduce/git/tripleo-quickstart-extras pull ||\
  git clone -b dev https://github.com/bogdando/tripleo-quickstart-extras \
    /var/tmp/reproduce/git/tripleo-quickstart-extras
git -C /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer pull ||\
  git clone -b in_container https://github.com/bogdando/ansible-role-tripleo-ci-reproducer \
    /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer

ln -sf /var/tmp/reproduce/git/tripleo-quickstart-extras/roles/* /var/tmp/reproduce/roles/
ln -sf /var/tmp/oooq/roles/* /var/tmp/reproduce/roles/
ln -sf /var/tmp/reproduce/git/tripleo-quickstart-extras/roles/* /var/tmp/reproduce/roles/
ln -sf /var/tmp/oooq/roles/* /var/tmp/reproduce/roles/
ln -sf /var/tmp/oooq/library/* /var/tmp/reproduce/library/
ln -sf /var/tmp/reproduce/git/tripleo-quickstart-extras/playbooks/* /var/tmp/reproduce/playbooks/
ln -sf /var/tmp/oooq/playbooks/* /var/tmp/reproduce/playbooks/
ln -sf /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer /var/tmp/reproduce/roles/
ln -sf /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer/playbooks/* /var/tmp/reproduce/playbooks/
ln -sf /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer/playbooks/* ${LWD}/playbooks/

./reproducer-zuul-based-quickstart.sh -w /var/tmp/reproduce -e @extra.yaml -l \
--ssh-key-path /var/tmp/.ssh/gerrit -e restore_snapshot=true -e os_autohold_node=false \
-e zuul_build_sshkey_cleanup=false -e container_mode=docker \
-e upstream_gerrit_user=$USER -e rdo_gerrit_user=$USER -e non_root_user=$USER -e non_root_group=$USER \
-e ansible_user=${1:-zuul} -e ansible_user_id=$USER -e teardown=$TEARDOWN -e install_path=$LWD
