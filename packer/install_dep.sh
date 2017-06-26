#!/bin/bash
set -ux
mkdir -p /home/${USER}/.ssh
echo "${USER} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USER}
set +u
easy_install pip
pip install -U virtualenvwrapper
echo 'export WORKON_HOME=~/Envs' >> ${HOME}/.bashrc
. $HOME/.bashrc
mkdir -p ~/Envs
echo 'export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python' >> ${HOME}/.bashrc
echo '. /usr/bin/virtualenvwrapper.sh' >> ${HOME}/.bashrc
. $HOME/.bashrc
. /usr/bin/virtualenvwrapper.sh
mkvirtualenv oooq
workon oooq
cd /tmp/oooq
pip install --no-cache-dir -r requirements.txt -r quickstart-extras-requirements.txt
# https://review.openstack.org/477482
pip install --no-cache-dir jinja2>=2.9.6
