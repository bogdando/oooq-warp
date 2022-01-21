#!/bin/bash
set -e
if [ "$TEARDOWN" = "true" ]; then
  rm -rf /var/tmp/reproduce/git /var/tmp/reproduce/roles/
  git clone -b in_container https://github.com/bogdando/ansible-role-tripleo-ci-reproducer /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer
  git clone -b dev https://github.com/bogdando/tripleo-quickstart /var/tmp/reproduce/git/tripleo-quickstart
  git clone -b dev https://github.com/bogdando/tripleo-quickstart-extras /var/tmp/reproduce/git/tripleo-quickstart-extras

  mkdir -p /var/tmp/reproduce/roles/ /var/tmp/reproduce/playbooks
  ln -sf /var/tmp/reproduce/git/tripleo-quickstart-extras/roles/* /var/tmp/reproduce/roles/
  ln -sf /var/tmp/oooq/roles/* /var/tmp/reproduce/roles/
  ln -sf /var/tmp/reproduce/git/tripleo-quickstart-extras/roles/* /var/tmp/reproduce/roles/
  ln -sf /var/tmp/oooq/roles/* /var/tmp/reproduce/roles/
  ln -sf /var/tmp/oooq/library/* /var/tmp/reproduce/library/
  ln -sf /var/tmp/reproduce/git/tripleo-quickstart-extras/playbooks/* /var/tmp/reproduce/playbooks/
  ln -sf /var/tmp/oooq/playbooks/* /var/tmp/reproduce/playbooks/
  ln -sf /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer /var/tmp/reproduce/roles/
  ln -sf /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer/playbooks/* /var/tmp/reproduce/playbooks/

  tar xf reproducer-zuul-based-quickstart.tar ||:
else
  git -C /var/tmp/reproduce/git/tripleo-quickstart pull
  git -C /var/tmp/reproduce/git/tripleo-quickstart-extras pull
  git -C /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer pull
fi
cp -f launcher-playbook.yaml /var/tmp/reproduce/

./reproducer-zuul-based-quickstart.sh -w /var/tmp/reproduce -e @extra.yaml -l \
--ssh-key-path /var/tmp/.ssh/gerrit -e create_snapshot=true -e os_autohold_node=false \
-e zuul_build_sshkey_cleanup=false -e container_mode=docker -e ansible_user=${1:-zuul} \
-e upstream_gerrit_user=$USER -e rdo_gerrit_user=$USER -e ansible_user_id=$USER \
-e virthost_provisioning_interface=noop -e teardown=$TEARDOWN -e install_path=$LWD
