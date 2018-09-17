#!/bin/bash
set -ux
useradd -m -p '' -U ${USER}||:
mkdir -p /home/${USER}/.ssh
echo "${USER} ALL=NOPASSWD:ALL" > /etc/sudoers.d/${USER}
echo "Defaults:${USER} !requiretty" /etc/sudoers.d/${USER}
chmod 0440 /etc/sudoers.d/${USER}
set +u
easy_install pip
pip install -U virtualenvwrapper || exit 1
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
pip install -U pip || exit 1
pip install -U pbr || exit 1
pip install -r requirements.txt -r quickstart-extras-requirements.txt || exit 1
pip install dumb-init || exit 1
chown -R ${USER}:${USER} /home/${USER}
