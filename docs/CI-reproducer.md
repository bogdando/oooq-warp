# Zuul Based TripleO CI Reproducer (Libvirt Mode)

> **NOTE** This guide suggests using forks (no bueno :-( ).
> But those are rebased from time to time, and some patches are getting merged upstream.
> * [ansible-role-tripleo-ci-reproducer](https://github.com/bogdando/ansible-role-tripleo-ci-reproducer/tree/in_container)
>   to run things wrapped in a container, and to support custom `mirror_fqdn` for custom images;
> * [tripleo-quickstart-extras](https://github.com/bogdando/tripleo-quickstart-extras/tree/dev)
    to use snapshot-libvirt, and to support custom `mirror_fqdn` for custom images;
> * [tripleo-quickstart](https://github.com/bogdando/tripleo-quickstart/tree/dev)
    with static multi-node libvirt nodepool and some py3 shenanigans mostly.

Additionally to the already present docker, install docker-compose onto your
host. Then teardown the docker volumes, if any:

```
$ docker volume rm httpd logs pki playbooks projects reproduce zuul
```

If any volumes are in use, exit the oooq-warp container, if in it, then try to
remove the containers that can use it and repeat the previous command:
```
$ docker rm -f tripleo-ci-reproducer_logs_1 tripleo-ci-reproducer_fingergw_1 \
tripleo-ci-reproducer_executor_1 tripleo-ci-reproducer_web_1 \
tripleo-ci-reproducer_merger1_1 tripleo-ci-reproducer_merger0_1 \
tripleo-ci-reproducer_scheduler_1 tripleo-ci-reproducer_launcher_1 \
tripleo-ci-reproducer_mysql_1 tripleo-ci-reproducer_zk_1 \
tripleo-ci-reproducer_gerrit_1 tripleo-ci-reproducer_logs_1 \
tripleo-ci-reproducer_gerritconfig_1
```
or maybe that one:
```
$ docker rm -f tripleocireproducer_logs_1 tripleocireproducer_fingergw_1 \
tripleocireproducer_executor_1 tripleocireproducer_web_1 \
tripleocireproducer_merger1_1 tripleocireproducer_merger0_1 \
tripleocireproducer_scheduler_1 tripleocireproducer_launcher_1 \
tripleocireproducer_mysql_1 tripleocireproducer_zk_1 \
tripleocireproducer_gerrit_1 tripleocireproducer_logs_1 \
tripleocireproducer_gerritconfig_1
```

Prepare a gerrit key for the example gerrit and local users named donkey:
```
$ mkdir -p /donkeys
$ ssh-keygen -b 1024 -t rsa -f /donkeys/donkey -N "" -q
$ ssh-keygen -yf  /donkeys/donkey > /donkeys/donkey.pub
```
Add that public key to the donkey's SSH keys in the opendev and rdo gerrits.
Then start the wrapper container (or see below how to run on host):
```
$ USER=donkey GERRITKEY=/donkeys/donkey TEARDOWN=true \
  LWD=/opt/.quickstart RAMFS=false RELEASE=master \
  TERMOPTS=-it ./oooq-warp.sh
```
Note, `GERRITKEY` defaults to `$HOME/.ssh/id_rsa` for the given user `donkey`.
It must point to the private SSH key used to connect the upstream opendev/rdo
gerrits w/o a password set for the key. This assumes the gerrit user name is
also `donkey` for opendev and rdo gerrits.

Download the reproducer by `<url>`, take it from any executed Zuul CI job for
TripleO projects. And run the reproducer using the forked repo:

```
(oooq) $ wget -O reproducer-zuul-based-quickstart.tar <url>
(oooq) $ tar xf reproducer-zuul-based-quickstart.tar
(oooq) $ tripleo-reproducer.sh
```
If you plan to keep subnode VMs for future use and exit the wrapping container,
run ``save-state.sh`` before exiting it.

## Retry from the subnodes snapshots created earlier
To retry it from the `${LWD}/vm_images/*.bak` snapshots:
```
(oooq) $ sudo chmod -R a+rwt ~/tripleo-ci-reproducer/logs
(oooq) $ tripleo-reproducer-restore.sh
```

## Retry subnodes configuration without touching existing VMs

To omit libvirt provision and rebooting subnodes, add ``-e teardown=false``

## Running on host without the wrapper container

If you run CI reproducer on a disposable Centos/Fedora/RHEL host with libvirt,
kvm, ansible and docker/podman pre-installed, a few extra steps are needed (here
logged in as the example user donkey):
```
$ cat > ~/.ssh/config << EOF
Host localhost
        Hostname localhost
        User zuul
        PubkeyAuthentication yes
        IdentityFile /donkeys/donkey # the donkey's gerrit key
Host review.opendev.org
        Hostname review.opendev.org
        User donkey
        PubkeyAuthentication yes
        IdentityFile /donkeys/donkey # the donkey's gerrit key
Host review.rdoproject.org
        Hostname review.rdoproject.org
        User donkey
        PubkeyAuthentication yes
        IdentityFile /donkeys/donkey # the donkey's gerrit key
EOF
$ chmod 600 ~/.ssh/config

$ eval $(ssh-agent)
$ ssh-keygen -b 1024 -t rsa -f ~/.ssh/id_rsa -N "" -q
$ ssh-keygen -yf ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
$ cp -f ~/.ssh/id_rsa ~/.ssh/id_rsa.agent
$ cp -f ~/.ssh/id_rsa.pub ~/.ssh/id_rsa.pub.agent
$ chmod 0600 ~/.ssh/id*
$ sudo mkdir -p /root/.ssh
$ sudo cp -f ~/.ssh/id* /root/.ssh
$ ssh-add ~/.ssh/id_rsa.agent
$ ssh-add ~/.ssh/id_rsa

$ ./reproducer-zuul-based-quickstart.sh -w /var/tmp/reproduce -e @extra.yaml -l \
--ssh-key-path /donkeys -e os_autohold_node=true \
-e zuul_build_sshkey_cleanup=false -e container_mode=docker \
-e upstream_gerrit_user=donkey -e rdo_gerrit_user=donkey
```

If it fails to resize undercloud VM disk, open `a+r` for `/boot/vmlinuz*` for the
host OS, then repeat the failed command in the wrapper container manually, like:
```
$ virt-resize -v -x --expand /dev/sda1 \
    ~/tripleo-ci-reproducer/undercloud.qcow2 \
    ~/tripleo-ci-reproducer/undercloud-resized.qcow2
```

> **NOTE**: If docker/compose CLI fails in container and autohold cannot be set
> for a zuul job, run it on the host e.g.:
```
$ docker exec tripleo-ci-reproducer_scheduler_1 zuul autohold --project test1 \
 --tenant tripleo-ci-reproducer --job tripleo-ci-centos-8-standalone-dlrn-hash-tag \
 --reason reproducer_forensics
```

## An extra.yaml example
```
libvirt_packages: [] # only when running in a wrapper container                                                                                                                                   │·······························
# or mirror.mtl01.inap.opendev.org, mirror01.ord.rax.opendev.org
mirror_path: mirror.regionone.rdo-cloud.rdoproject.org
custom_nameserver: 208.67.222.220
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
libvirt_volume_path: /opt/.quickstart/vm_images # only when in a wrapper container
mergers: 2
play_kube: false
rootless: false
release: master
virthost_provisioning_interface: noop
```
## Centos 8

You can [Cloud Images](https://cloud.centos.org/centos/8/x86_64/images/) or try
OS Infra images from `https://nb01.opendev.org/images`,
`https://nb02.opendev.org/images`, or `https://nb04.opendev.org/images`.
There is also `http://images.rdoproject.org/CentOS-8-x86_64-GenericCloud.qcow2`.
Some of them may not have python or yum installed:
```
$ sudo virt-customize -a centos-8.qcow2 --run-command \
    'dnf -y install python3 yum screen'
$ md5sum centos-8.qcow2
```

Add the stanza below to deploy on Centos 8 subnodes:
```
# WTF https://github.com/ansible/ansible/issues/43286
# try whatever works for you:
#ansible_python_interpreter: "/usr/bin/env python3"
ansible_python_interpreter: /usr/bin/python3
mirror_fqdn: mirror.mtl01.inap.opendev.org
pypi_fqdn: mirror01.ord.rax.opendev.org
package_mirror: http://mirror.centos.org/centos
images:
  - name: undercloud
    url: file://{{ local_working_dir }}/centos-8.qcow2
    md5sum: <updated md5>
    type: qcow2
  - name: overcloud
    url: file://{{ local_working_dir }}/centos-8.qcow2
    md5sum: <updated md5>
```

## Build Logs?
The ansible log can be found in `/var/tmp/reproduce/ansible.log`.
At the subnodes, watch for the tails of
`*log /tmp/console*`.
