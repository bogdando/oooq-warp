#!/bin/bash
sudo chmod -R a+rwt ~/tripleo-ci-reproducer/logs
./reproducer-zuul-based-quickstart.sh -w /var/tmp/reproduce -e @extra.yaml -l \
--ssh-key-path /var/tmp/.ssh/gerrit -e restore_snapshot=true -e os_autohold_node=true \
-e zuul_build_sshkey_cleanup=false -e container_mode=docker \
-e upstream_gerrit_user=$USER -e rdo_gerrit_user=$USER \
-e ansible_user=zuul -e ansible_user_id=$USER -e teardown=$TEARDOWN
