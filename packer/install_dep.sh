#!/bin/bash
easy_install pip
pip install --upgrade virtualenvwrapper || exit 1
dnf install -y python3-virtualenv
export WORKON_HOME=/var/tmp/Envs
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python
mkdir -p $WORKON_HOME
. /usr/bin/virtualenvwrapper.sh
python3 -m venv --system-site-packages oooq /var/tmp/Envs/oooq
workon oooq
cd /tmp/oooq
set -e
pip install --upgrade pip
pip install --upgrade pbr
pip install --upgrade setuptools
pip install --no-use-pep517 -r requirements.txt -r quickstart-extras-requirements.txt
pip install dumb-init
# Required for the new CI reproducer
pip install virtualenv bindep
pip install docker
pip install docker-compose

# my hacks for zuul reproducer in libvirt mode from a container
git clone -b in_container https://github.com/bogdando/ansible-role-tripleo-ci-reproducer \
 /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer
git clone -b dev https://github.com/bogdando/tripleo-quickstart /var/tmp/reproduce/git/tripleo-quickstart
git clone -b dev https://github.com/bogdando/tripleo-quickstart-extras /var/tmp/reproduce/git/tripleo-quickstart-extras
mkdir -p /var/tmp/reproduce/roles/
ln -sf /var/tmp/reproduce/git/tripleo-quickstart-extras/roles/* /var/tmp/reproduce/roles/
