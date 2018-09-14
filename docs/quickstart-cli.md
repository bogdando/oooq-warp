# Quickstart CLI wrapper (quickstart.sh)

Use the ``quickstart.sh`` wrapper as usual but in the wrapper container. For example,
using localhost as virthost and privileged libvirt mode:
```
(oooq) quickstart.sh -R master -e dlrn_hash_tag=current-tripleo --no-clone \
         -N config/nodes/1ctlr_1comp.yml \
         -E config/environments/dev_privileged_libvirt.yml \
         -E /var/tmp/scripts/vars/quickstart.yaml \
         -t all -T all localhost
```
Save the produced state with the ``save-state.sh --sync`` wrapper.

> **NOTE** It is an important step to keep the disconnected working dirs and image caches
> content in sync.

To access the VM via SSH use

```
(oooq) save-state.sh
(oooq) ssh -F $LWD/ssh.config.local.ansible undercloud
```

## Reprovisioning quickly (warp! warp! warp!)

To reprovision with the cached images, add the original command:
```
-E /var/tmp/scripts/vars/quickstart-cached-images.yaml -T none
```

> **FIXME**  It always stops the halfway of provisioning currently, as you manually
> need to update the virthost authorized keys with the generated SSH keys. So
> you'll need to continue it like in the given example command above.

Running with ``--clean`` will recreate the venv. But it makes more sense just
to rebuild the container and never use the ``--clean`` parameter run-time.

If you only want to re-install/update in-place UC and skip anything that
predates that even faster then doing idempotent ansible apply, add
```
--skip-tags teardown-all,provision,environment,libvirt,undercloud-inventory \
  -T none -I
```
The same, but going stright to overcloud deployment:
```
--skip-tags provision,environment,libvirt,undercloud-setup,undercloud-install,undercloud-post-install,tripleo-validations \
  -e docker_registry_namespace_used=tripleo-master -T none -I -t all
```
``docker_registry_namespace_used`` Needs to be defined as we skip the
``undercloud-install`` tag.
