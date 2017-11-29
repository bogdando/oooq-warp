This is WIP guide to deploy containerized undercloud all-in-one on RDO cloud.

**Note:** replace all `<example values>` with real ones!

```
$ export USER=<your local user name with sudo (here fuser)>
$ mkdir -p ~/.config/openstack
$ export WORKSPACE=<some path like /opt/oooq>
$ sudo mkdir -p $WORKSPACE
$ sudo chown -R ${USER}: "$WORKSPACE"
```

Copy your rdo cloud user's pem/pub key files into `~/.config/openstack/`
and `$WORKSPACE`.
Install docker, git locally.
Clone repos and provision a heat stack on RDO cloud with TraaS:

```
$ cat > ~/.config/openstack/clouds.yaml << EOF_CAT
clouds:
  rdo-cloud:
    auth:
      auth_url: https://phx2.cloud.rdoproject.org:13000
      project_name: <rdo cloud user>
      username: <rdo cloud user>
      password: <rdo cloud pass>
    region: RegionOne
EOF_CAT

$ cd ~
$ git clone https://github.com/openstack/tripleo-quickstart.git
$ git clone -b dev https://github.com/bogdando/oooq-warp.git
$ git clone -b wip https://github.com/bogdando/traas.git

$ cd ~/traas
$ openstack --os-cloud rdo-cloud stack create foo \
  -t templates/traas-oooq.yaml  \
  -e templates/traas-oooq-resource-registry.yaml \
  -e templates/example-environments/rdo-cloud-oooq-env-uc.yaml
```

Wait for provisioning ends, just watch for 'foo-undercloud login:' shown in
`openstack --os-cloud rdo-cloud console log show foo-undercloud` outputs.
Prepare ansible inventory variables:

```
$ cd ~/oooq-warp
$ cp vars/undercloud-only-traas.yaml custom.yaml
```

Edit `vars/inventory-traas.yaml` with the RDO cloud creds used above.
Generate static inventory, SSH config and deploy:

```
$ OOOQ_PATH="${HOME}/tripleo-quickstart" OOOQE_BRANCH=rdocloud ./oooq-warp.sh
# execute from container (oooq prompt):
(oooq) PLAY=oooq-traas.yaml create_env_oooq.sh
(oooq) PLAY=oooq-traas-under.yaml create_env_oooq.sh
```

To login deployed openstack all-in-one (tripleo undercloud), execute from your
local host:

```
$ ssh -F ${WORKSPACE}/ssh.config.ansible undercloud
```