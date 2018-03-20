#!/bin/bash
set -ux
mkdir -p /home/${USER}/.ssh
echo "${USER} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USER}
set +u
easy_install pip
pip install -U virtualenvwrapper
echo 'export WORKON_HOME=/home/${USER}/Envs' >> /home/${USER}/.bashrc
. /home/${USER}/.bashrc
mkdir -p /home/${USER}/Envs
echo 'export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python' >> /home/${USER}/.bashrc
echo '. /usr/bin/virtualenvwrapper.sh' >> /home/${USER}/.bashrc
. home/${USER}/.bashrc
. /usr/bin/virtualenvwrapper.sh
mkvirtualenv oooq
workon oooq
cd /tmp/oooq
pip install --no-cache-dir -r requirements.txt -r quickstart-extras-requirements.txt
sudo chown -R ${USER}:${USER} /home/${USER}
