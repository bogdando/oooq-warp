# Example: all-in-one undercloud to deploy openshift

## Libvirt

> **NOTE** Setting ``update_images: true`` is needed to setup root password
> for VM. It drastically extends the image build time! Uncomment
> ``undercloud_use_custom_boot_images``, if you already have kernel images.

```
(oooq) PLAY=oooq-libvirt-provision.yaml create_env_oooq.sh \
           -e@/var/tmp/scripts/tht/config/general_config/featureset127.yml \
           -e update_images=true \
           -e force_cached_images=true -e image_cache_expire_days=300 #\
           #-e undercloud_use_custom_boot_images=true \
           #-e undercloud_custom_initrd=${IMAGECACHE}/overcloud-full.initrd \
           #-e undercloud_custom_vmlinuz=${IMAGECACHE}/overcloud-full.vmlinuz \

(oooq) PLAY=oooq-libvirt-under-openshift.yaml create_env_oooq.sh \
           -e@/var/tmp/scripts/tht/config/general_config/featureset127.yml
```

## Public openstack, like RDO cloud

First, provision a vanilla centos 7.x VM, e.g.:
```
$ openstack server create --image \
    $(openstack image list --long -f value -c ID --property latest=centos-7-latest) \
    --flavor m1.large --key-name <my-public-cloud-key> \
    --nic net-id=<private> --nic net-id=<private2> undercloud

$ openstack floating ip set --port  <id_from_the_private_subnet> <floating_ip>
```
Then generate a static inventory (update ``vars/inventory-traas.yaml`` with
your public cloud creds) and deploy, using a slightly modified command than it
was used above for the example libvirt deployment, like:
```
(oooq) rm -rf $VIRTUAL_ENV/ansible_facts_cache hosts
(oooq) PLAY=oooq-traas.yaml create_env_oooq.sh
(oooq) PLAY=oooq-libvirt-under-openshift.yaml create_env_oooq.sh \
  -e@/var/tmp/scripts/tht/config/general_config/featureset127.yml -v \
  -e undercloud_network_cidr=192.168.253.0/24 \
  -e undercloud_external_network_cidr=192.168.0.0/24 -e \
  undercloud_undercloud_output_dir=/home/centos -e undercloud_user=centos
```
Here 192.168.253.0/24 belongs to my `private2` net, which corresponds to
internal/ctlplane net, and 192.168.0.0/24 - to the `private` net, which is
treated as a "public" net for this example, just to illustrate the network
layout.
