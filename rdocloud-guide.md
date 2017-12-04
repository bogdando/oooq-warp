This is WIP guide to deploy containerized undercloud all-in-one on RDO cloud.

**Note:** replace all `<example values>` with real ones!

```
$ export USER=<your local logged in user name>
$ mkdir -p ~/.config/openstack
$ export WORKSPACE=<some path like /opt/oooq>
$ sudo mkdir -p $WORKSPACE
$ sudo chown -R ${USER}: "$WORKSPACE"
$ sudo chmod 750 "$WORKSPACE"
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
$ git clone https://github.com/bogdando/oooq-warp.git
$ git clone -b dev https://github.com/bogdando/traas.git
```
Customize `traas/templates/example-environments/rdo-cloud-oooq-env-uc.yaml`
with your creds/flavors/images used. Do not set overcloud controller/compute
counts above zero, you will not need them for all-in-one undercloud setup.

**Security note** : Set `ssh_ingress_cidr` and `cluster_ingress_cidr` to your
local host's public IP (in a '/32' CIDR notaion) in order to restrict access to
deployed services from outside. Use ``curl https://api.ipify.org`` to get that
public address.

Create an additional 'private2' tenant netwrok on RDO host cloud, which is
required for undercloud intranet-only "floating" IPs. No subnet or router
connection is needed for that network.

According to RDO cloud tenant configuration guide, you should already have
a 'private' and a public networks created. Traas relies on these hardcoded
names from that guide (real IP is hidden with an 'x'):

```
openstack --os-cloud rdo-cloud network list -c Name
+----------------+
| Name           |
+----------------+
| private2       |
| private        |
| 3x.xx.xx.0/22 |
+----------------+
```

Then create a heat stack:
```
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
Update `undercloud_network_cidr` and `undercloud_external_network_cidr`
in `vars/undercloud-networking.yaml` to correspond to the private networks and
subnets you created for your RDO cloud's tenant (traas expects the networks are
pre-created). Generate static inventory, SSH config and deploy:

```
$ TEARDOWN=true \
  OOOQ_PATH="${HOME}/tripleo-quickstart" \
  OOOQE_BRANCH=rdocloud \
  ./oooq-warp.sh

# execute from container (oooq prompt):
(oooq) PLAY=oooq-traas.yaml create_env_oooq.sh
(oooq) PLAY=oooq-traas-under.yaml create_env_oooq.sh
```

To login deployed openstack all-in-one (tripleo undercloud), execute from your
local host:

```
$ ssh -F ${WORKSPACE}/ssh.config.ansible undercloud
```
