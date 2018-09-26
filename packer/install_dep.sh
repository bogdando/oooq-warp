#!/bin/bash
easy_install pip
pip install -U virtualenvwrapper || exit 1
export WORKON_HOME=/var/tmp/Envs
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python
mkdir -p $WORKON_HOME
. /usr/bin/virtualenvwrapper.sh
mkvirtualenv oooq
workon oooq
cd /tmp/oooq
pip install -U pip || exit 1
pip install -U pbr || exit 1
pip install -r requirements.txt -r quickstart-extras-requirements.txt || exit 1
pip install dumb-init || exit 1
