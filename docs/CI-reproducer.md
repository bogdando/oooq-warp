# CI reproducer

Additionally to the already present docker, install docker-compose onto your
host.  Start the wrapper container almost as usually, but with a non-existant
host user, like:
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
(oooq) $ sudo rm -rf /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer
(oooq) $ git clone -b in_container \
  https://github.com/bogdando/ansible-role-tripleo-ci-reproducer \
  /var/tmp/reproduce/git/ansible-role-tripleo-ci-reproducer
(oooq) $ bash -x reproducer-zuul-based-quickstart.sh   -w /var/tmp/reproduce -e @extra.yaml -l
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
ssh_path: /var/tmp/.ssh/gerrit # this is a mandatory, do not change
:
```
