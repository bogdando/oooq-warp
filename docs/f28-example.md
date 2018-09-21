# An example Fedora 28 libvirt deployment

It needs the quickstart patches (apply it to the locally clonned repos):

* https://review.openstack.org/#/q/topic:localcon+(status:open+OR+status:merged)
* https://review.openstack.org/#/c/602485/
* https://review.openstack.org/#/c/603069/
* https://review.openstack.org/#/c/595566/

Or just use the dev forks with those included:
```
$ git clone -b dev https://github.com/bogdando/tripleo-quickstart.git /var/tmp/tripleo-quickstart
$ git clone -b dev https://github.com/bogdando/tripleo-quickstart-extras.git /var/tmp/tripleo-quickstart-extras
```

A few configurations, pick what fits your case:
```
$ sudo useradd -m -p '' -U -G root bogdando # only works this way yet :)
$ echo 'bogdando ALL=NOPASSWD:ALL' | sudo tee /etc/sudoers
$ sudo dnf install libvirt docker qemu-kvm libguestfs wget git
$ sudo usermod -aG libvirt bogdando
$ sudo systemctl start libvirtd
$ sudo systemctl start docker
$ sudo chmod a+r /boot/vmlinuz* # or unset LIBGUESTFS_BACKEND_SETTINGS instead
$ mkdir -p "$LWD" "$IMAGECACHE" "$IMAGECACHEBACKUP"
```

Fetch Fedora 28 cloud image locally and do some magic for quickstart to catch up md5:
```
$ wget https://download.fedoraproject.org/pub/fedora/linux/releases/28/Cloud/x86_64/images/Fedora-Cloud-Base-28-1.1.x86_64.qcow2 \
  -O ${IMAGECACHE}/Fedora-Cloud-Base-28-1.1.x86_64.qcow2
$ md5sum ${IMAGECACHE}/Fedora-Cloud-Base-28-1.1.x86_64.qcow2 > ${IMAGECACHEBACKUP}/Fedora-Cloud-Base-28-1.1.x86_64.qcow2.md5
$ name="$(awk '{print $1}' ${IMAGECACHEBACKUP}/Fedora-Cloud-Base-28-1.1.x86_64.qcow2.md5).qcow2"
$ cp ${IMAGECACHE}/Fedora-Cloud-Base-28-1.1.x86_64.qcow2 ${IMAGECACHEBACKUP}/${name}
```

Start the wrapper Fedora 28 container (uses the pre-built images on dockerhub):
```
$ sudo su - bogdando
$ git clone https://github.com/bogdando/oooq-warp.git
$ cd oooq-warp
$ . vars/fedora28.env
$ TEARDOWN=true RAMFS=true ./oooq-warp.sh
```

Proceed with provisioning a libvirt env:
```
(oooq) quickstart.sh --no-clone \
         -E config/environments/dev_privileged_libvirt.yml \
         -E /var/tmp/scripts/vars/quickstart.yaml \
         -E /var/tmp/scripts/vars/fedora28.yaml \
         -t provision,environment,libvirt,undercloud-inventory -T all \
	 localhost
(oooq) sed -i -r 's/^undercloud(.*$)/node\1/g' hosts
(oooq) sed -i -r 's/^Host undercloud(.*$)/Host node\1/g' ssh.config.local.ansible
(oooq) git clone https://github.com/mwhahaha/tripleo-f28-testbed
(oooq) ansible-playbook -i hosts tripleo-f28-testbed/pre-provision.yml -e@tripleo-f28-testbed/tripleo-dlrn-data.yml
```
Note, adjust the default `external_network_cidr: 192.168.23.0/24`, if you have
conflicting CIDR for libvirt networks, like ``-e external_network_cidr=192.168.24.0/24``.

See also [troubleshooting libvirt envs](./troubleshoot.md) if you have other
issues.
