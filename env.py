#!/usr/bin/python
# -*- coding: utf-8 -*-
from copy import deepcopy
import os
import sys

from devops.helpers.templates import yaml_template_load
from devops.models import Environment


def create_config():
    env = os.environ

    conf_path = env['CONF_PATH']
    conf = yaml_template_load(conf_path)

    slaves_count = int(env['SLAVES_COUNT'])

    group = conf['template']['devops_settings']['groups'][0]
    defined = filter(lambda x: x['role'] == 'oooq-node',
                     group['nodes'])
    node_params = filter(lambda x: x['name'].endswith('slave-0'),
                         group['nodes'])[0]['params']

    for i in range(len(defined), slaves_count):
        group['nodes'].append(
            {'name': 'slave-{}'.format(i),
             'role': 'oooq-node',
             'params': deepcopy(node_params)})

    return conf


def _get_free_eth_interface(node):
    taken = [i['label'] for i in node['params']['interfaces']]
    iface = 'eth'
    index = 0
    while True:
        new_iface = '{}{}'.format(iface, index)
        if new_iface not in taken:
            return new_iface
        index += 1


def get_env():
    env = os.environ
    env_name = env['ENV_NAME']
    return Environment.get(name=env_name)


def get_slave_ips(env):
    slaves = env.get_nodes(role='oooq-node')
    ips = []
    for slave in slaves:
        ip = slave.get_ip_address_by_network_name('external').encode('utf-8')
        ips.append(ip)
    return ips


def define_from_config(conf):
    env = Environment.create_environment(conf)
    env.define()
    env.start()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(2)
    cmd = sys.argv[1]
    if cmd == 'create_env':
        config = create_config()
        define_from_config(config)
    elif cmd == 'get_slaves_ips':
        sys.stdout.write(str(get_slave_ips(get_env())))
