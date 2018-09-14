# Pre-flight checks for a warp jump

To start a scratch local dev env with libvirt and kvm:

Download the overcloud-full, undercloud and ironic-python-agent images and md5
files into ``IMAGECACHE``. Or omit that step if you want quickstart do that
for you based on the given ``dlrn_hash_tag``.

> **NOTE**: Backup those for future re-provision runs in ``${IMAGECACHEBACKUP}``!
> You may want to preserve the original images for future deployments.

Pick any of these sources:

* [The most recent, the less stable](https://images.rdoproject.org/master/delorean/current-tripleo/),
  for hardcore devs
* [(Non HTTPS link!) more stable and older images](http://artifacts.ci.centos.org/rdo/images/master/delorean/consistent/),
  it is also the default OOOQ choice ([HTTPS mirror](https://images.rdoproject.org/master/delorean/consistent/)).
* [The one](https://buildlogs.centos.org/centos/7/cloud/x86_64/tripleo_images/master/delorean/) from the
  [Docs](https://tripleo.org/basic_deployment/basic_deployment_cli.html).

When using ``overcloud_as_undercloud``, you may omit downloading the
`undercloud.qcow2` image.
