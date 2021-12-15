#!/bin/bash
set -e
git -C /var/tmp/reproduce/git/tripleo-quickstart pull
git -C /var/tmp/reproduce/git/tripleo-quickstart-extras pull
git -C /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer pull

tar xf reproducer-zuul-based-quickstart.tar ||:
cp -f launcher-playbook.yaml /var/tmp/reproduce/

./reproducer-zuul-based-quickstart.sh -w /var/tmp/reproduce -e @extra.yaml -l \
--ssh-key-path /var/tmp/.ssh/gerrit -e create_snapshot=true -e os_autohold_node=true \
-e zuul_build_sshkey_cleanup=false -e container_mode=docker -e ansible_user=zuul \
-e upstream_gerrit_user=$USER -e rdo_gerrit_user=$USER -e ansible_user_id=$USER \
-e virthost_provisioning_interface=noop -e teardown=$TEARDOWN
