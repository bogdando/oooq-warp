# Example: local libvirt OVB setup

The expected workflow is:

* provision a libvirt env, it creates a running undercloud VM and shut-off VMs
  from the ``overcloud_nodes`` passed.
* Install undercloud as a separate step (optional, depends on the next step)
* Deploy a particular quickstart's CI featureset, given a nodes-file and/or a
  config release file, added your custom ansible CLI args and ``CUSTOMVARS``.
* Proceed with OVB, f.e. executred from the provided ``reproduce-quickstart.sh``.

Example commands (``(oooq)`` represents the shell prompt in the wrapper container):

* Provision the long path with building images et al
```
(oooq) ./quickstart.sh --install-deps
(oooq) PLAY=oooq-libvirt-provision-build.yaml create_env_oooq.sh \
           -e@config/nodes/1ctlr_1comp.yml \
           -e@config/release/master.yml \
           -e@/var/tmp/scripts/custom.yaml \
           -e@/var/tmp/scripts/tht/config/general_config/featureset062.yml
```
Add the generated public key into the host's ``USER`` ``authorized_keys`` file.

> **NOTE** The ``dlrn_hash_tag`` value must be matching the version in the
> source URL of the downloaded images. Do not attempt to override
> ``dlrn_hash`` top-scope as it breaks the fact auto-eval in quickstart repo-setup!

* Install undercloud (keeping in mind fs062 for overcloud has top precedence)
```
(oooq) export HOST_BREXT_IP=192.168.23.1
(oooq) ./quickstart.sh -R master -n -I -T none -t all \
           -N config/nodes/1ctlr_1comp.yml \
           -E /var/tmp/scripts/vars/undercloud-local.yaml \
           -E /var/tmp/scripts/custom.yaml \
           -E /var/tmp/scripts/tht/config/general_config/featureset062.yml \
           -p quickstart-extras-undercloud.yml \
           -e transport=local \
           -e vbmc_libvirt_uri="qemu+ssh://${USER}@${HOST_BREXT_IP}/session?socket=/run/libvirt/libvirt-sock&keyfile=/root/.ssh/id_rsa_virt_power&no_verify=1&no_tty=1" \
           localhost
```
> **FIXME**: the socket path is hardcoded in quickstart for RHEL OS family,
> so we have to override the ``vbmc_libvirt_uri`` and manually evaluate ``HOST_BREXT_IP``.
> To verify the connection, run from the undercloud node deployed (substitute with real values):
> ```
> $ sudo virsh connect "qemu+ssh://${USER}@${HOST_BREXT_IP}/session?socket=/run/libvirt/libvirt-sock&keyfile=/root/.ssh/id_rsa_virt_power&no_verify=1&no_tty=1"
> ```

* On undercloud VM, configure ``USER`` to
  access the docker CLI w/o sudo (substitute with the real value):
```
$ sudo usermod -aG root $USER
$ sudo usermod -aG dockerroot $USER
```

* Deploy overcloud from the given featureset and nodes config

> **NOTE** A known issue is that sometimes the docker registry distribution
> dies silently on the undercloud node. You can fix that with starting a custom
> container for the registry like:
> ```
> $ docker run --restart=always -dit -p 8787:5000 \
>       -v /var/lib/docker-registry:/var/lib/registry \
>       --name registry docker.io/library/registry
> ```

```
(oooq) ./quickstart.sh -R master -n -I -T none -t all \
           -S tripleo-validations \
           -p quickstart-extras-overcloud-prep.yml \
           -N config/nodes/1ctlr_1comp.yml \
           -E /var/tmp/scripts/vars/undercloud-local.yaml \
           -E /var/tmp/scripts/custom.yaml \
           -E /var/tmp/scripts/tht/config/general_config/featureset062.yml \
           -e transport=local localhost

(oooq) ./quickstart.sh -R master -n -I -T none -t all \
           -S tripleo-validations \
           -p quickstart-extras-overcloud.yml \
           -N config/nodes/1ctlr_1comp.yml \
           -E /var/tmp/scripts/vars/undercloud-local.yaml \
           -E /var/tmp/scripts/custom.yaml \
           -E /var/tmp/scripts/tht/config/general_config/featureset062.yml \
           -e transport=local localhost
```
> **NOTE** A known issue is that sometimes undercloud node cannot be connected
> because of the missing/bad ``id_rsa_undercloud`` key. Exit and re-enter a new
> wrapper container to fix that.

* Deploy your OVB setup on top

## Respinning a failed local libvirt env

If you want to reuse the existing (already customized by oooq) images and omit
all of the long playing build/provisioning steps:
* Export ``TEARDOWN=false`` then rerun the deploy inside of the
  container or start a new container.

To start a new libvirt env from the scratch:

* remove existing VMs' snapshots,
* exit the wrapper container,
* start a new container with ``TEARDOWN=true ./oooq-warp.sh``, or the like.

> **NOTE** When rebuilding from the scratch, you can still configure quickstart
> to re-use the kernel/latest fetched images from
> the ``IMAGECACHEBACKUP`` dir, for example:
> ```
> (oooq) PLAY=oooq-libvirt-provision-build.yaml create_env_oooq.sh \
>            -e@config/nodes/1ctlr_1comp.yml \
>            -e@config/release/master.yml \
>            -e@/var/tmp/scripts/custom.yaml \
>            -e@/var/tmp/scripts/tht/config/general_config/featureset062.yml \
>            -e undercloud_use_custom_boot_images=true \
>            -e undercloud_custom_initrd=${IMAGECACHE}/overcloud-full.initrd \
>            -e undercloud_custom_vmlinuz=${IMAGECACHE}/overcloud-full.vmlinuz \
>            -e force_cached_images=true -e image_cache_expire_days=30
> ```

If you want to include steps like re-fetching remote images and re-building
the kernel images et al, just remove the corresponding images from the
backup dir.
