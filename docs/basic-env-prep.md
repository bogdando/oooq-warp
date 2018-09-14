# Environment configuration basics

* Customize and export some additional env-specific vars, for example:

  ```
  $ export TEARDOWN=true # start a scratch environment, rebuild images, regen ssh keys.
  $ export USER=bogdando # undercloud/overcloud/SSH-admin/local virthost user
  $ export WORKSPACE=/tmp # must exist on the virthost and UC VM, libvirt revers to it
  $ export IMAGECACHE=/opt/cache # should exist on the virthost for persistent deployments
  $ export LWD=${HOME}/.quickstart # should exist on the virthost, may be equal to WORKSPACE
  $ export OOOQE_BRANCH=dev
  $ export OOOQE_FORK=johndoe
  $ export OOOQ_BRANCH=dev
  $ export OOOQ_FORK=johbdoe
  ```
  Or use ``OOOQE_PATH`` and/or ``OOOQ_PATH``, if you already have then clonned
  somewhere locally.

> **NOTE** If you chose ``RAMFS=true`` or non existing virthost paths, some/all
> of the WORKSPACE/IMAGECACHE/LWD paths may be ignored and become ephemeral
> (like the container run time only) ``/home/$USER`` and/or bind-mounted via
> ``/tmp`` host-path.  This speeds up provisioning steps, but eats a lot of RAM.
> Also note, using the current user home is not allowed for these paths,
> assuming the virthost is not a disbosable/throw-away host and logged in user
> should be affected by potentially destructive teardown actions.

* Start an interactive wrapper-container session:
  ```
  $ ./oooq-warp.sh
  ```
  See also non-interactive mode explained below.

At this point, the content of ``IMAGECACHEBACKUP`` will be recovered by
the ``IMAGECACHE`` path, and `latest-` sylinks will be auto-regenereted for
future quickstart provisioning playbooks use.

If you requested teardown and **really** want to nuke everything and fetch the
new images, run ``save-state.sh --purge``.
