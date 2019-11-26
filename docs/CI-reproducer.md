# CI reproducer

Additionally to the already present docker, install docker-compose onto your
host. Then teardown the docker volumes, if any:

```
$ docker volume rm httpd logs pki playbooks projects reproduce zuul
```

If any volumes are in use, try to remove the containers that can use it and
repeat the previous command:
```
$ docker rm -f tripleo-ci-reproducer_logs_1 tripleo-ci-reproducer_fingergw_1 \
tripleo-ci-reproducer_executor_1 tripleo-ci-reproducer_web_1 \
tripleo-ci-reproducer_merger1_1 tripleo-ci-reproducer_merger0_1 \
tripleo-ci-reproducer_scheduler_1 tripleo-ci-reproducer_launcher_1 \
tripleo-ci-reproducer_mysql_1 tripleo-ci-reproducer_zk_1 \
tripleo-ci-reproducer_gerrit_1 tripleo-ci-reproducer_logs_1 \
tripleo-ci-reproducer_gerritconfig_1
```
or
```
$ docker rm -f tripleocireproducer_logs_1 tripleocireproducer_fingergw_1 \
tripleocireproducer_executor_1 tripleocireproducer_web_1 \
tripleocireproducer_merger1_1 tripleocireproducer_merger0_1 \
tripleocireproducer_scheduler_1 tripleocireproducer_launcher_1 \
tripleocireproducer_mysql_1 tripleocireproducer_zk_1 \
tripleocireproducer_gerrit_1 tripleocireproducer_logs_1 \
tripleocireproducer_gerritconfig_1
```

Then start the wrapper container:
```
$ USER=donkey GERRITKEY=/donkeys/donkey TEARDOWN=true \
  LWD=/opt/.quickstart RAMFS=false \
  TERMOPTS=-it ./oooq-warp.sh
```
Note, `GERRITKEY` defaults to `$HOME/.ssh/id_rsa` for the given user. It must
point to the private SSH key used to connect the upstream opendev gerrit w/o
a password set for the key.

Download the reproducer by `<url>`, take it from any executed Zuul CI job for
TripleO projects. And run the reproducer using the forked repo:

```
(oooq) $ wget -O reproducer-zuul-based-quickstart.tar <url>
(oooq) $ tar xf reproducer-zuul-based-quickstart.tar
(oooq) $ sudo rm -rf /var/tmp/reproduce/git /var/tmp/reproduce/roles/
(oooq) $ git clone --depth 1 -b in_container \
  https://github.com/bogdando/ansible-role-tripleo-ci-reproducer \
  /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer
(oooq) $ git clone --depth 1 -b dev \
  https://github.com/bogdando/tripleo-quickstart \
 /var/tmp/reproduce/git/tripleo-quickstart
(oooq) $ git clone --depth 1 -b dev \
  https://github.com/bogdando/tripleo-quickstart-extras \
  /var/tmp/reproduce/git/tripleo-quickstart-extras
(oooq) $ mkdir -p /var/tmp/reproduce/roles/
(oooq) $ ln -sf /var/tmp/reproduce/git/tripleo-quickstart-extras/roles/* \
  /var/tmp/reproduce/roles/

(oooq) $ sudo rm -f ${LWD}/vm_images/*.bak
(oooq) $ ./reproducer-zuul-based-quickstart.sh -w /var/tmp/reproduce \
  -e @extra.yaml -l --ssh-key-path /var/tmp/.ssh/gerrit \
  -e create_snapshot=true -e os_autohold_node=false \
  -e zuul_build_sshkey_cleanup=false
```

Or to retry it from the `${LWD}/vm_images/*.bak` snapshots:
```
(oooq) $ sudo chmod a+r ${LWD}/vm_images/*
(oooq) $ sudo chown root:root ${LWD}/vm_images/*.qcow2
(oooq) $ sudo chmod -R a+rwt ~/tripleo-ci-reproducer/logs
(oooq) $ bash -x reproducer-zuul-based-quickstart.sh -w /var/tmp/reproduce -l \
  --ssh-key-path /var/tmp/.ssh/gerrit -e @extra.yaml -e restore_snapshot=true \
  -e os_autohold_node=false -e zuul_build_sshkey_cleanup=false
```

The custom `extra.yaml` example:
```
custom_nameserver:
  - 208.67.222.220
deploy_timeout: 360
compute_memory: 4096
compute_vcpu: 1
control_memory: 8192
control_vcpu: 2
undercloud_vcpu: 2
undercloud_memory: 8192
force_cached_images: true
image_cache_expire_days: 30
vxlan_networking: false
toci_vxlan_networking: false
modify_image_vc_root_password: r00tme
libvirt_volume_path: /opt/.quickstart/vm_images
mergers: 2
mirror_path: mirror01.ord.rax.openstack.org
```

The ansible log can be found in `/var/tmp/reproduce/ansible.log`.
At the subnodes, watch for the tails of
`*log /tmp/console* /var/log/tripleo-container-image-prepare.log
/var/log/paunch.log`.

Another example to deploy on Fedora 31 nodes:
```
mirror_fqdn: ftp.up.pt
pypi_fqdn: mirror01.ord.rax.openstack.org
ansible_python_interpreter: /usr/bin/python3
images:
  - name: undercloud
    url: file://{{ local_working_dir }}/Fedora-Cloud-Base-31-1.9.x86_64.qcow2
    md5sum: 726b5ea57013e6a71b1cddb25356cfe5
    type: qcow2
  - name: overcloud
    url: file://{{ local_working_dir }}/Fedora-Cloud-Base-31-1.9.x86_64.qcow2
    md5sum: 726b5ea57013e6a71b1cddb25356cfe5
    type: qcow2
... (the same content as above) ...
```
