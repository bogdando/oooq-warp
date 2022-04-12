This is WIP guide to deploy containerized undercloud all-in-one on PSI cloud.

**Note:** replace all `<example values>` with real ones!

```
$ export USER=<your local logged in user name>
$ mkdir -p ~/.config/openstack
$ export WORKSPACE=<some path like /opt/oooq>
$ sudo mkdir -p $WORKSPACE
$ sudo chown -R ${USER}: "$WORKSPACE"
$ sudo chmod 750 "$WORKSPACE"
```

Get your PSI application creds into `~/.config/openstack/clouds.yaml`
Install docker, git locally.
Clone repos and provision a heat stack on PSI cloud with TraaS:

```
$ cd ~
$ git clone https://github.com/openstack/tripleo-quickstart.git
$ git clone https://github.com/bogdando/oooq-warp.git
$ git clone https://github.com/bogdando/traas.git
```
Customize `traas/templates/example-environments/psi-env.yaml`
with your creds/flavors/images used. Do not set overcloud controller/compute
counts above zero, if you only an need all-in-one setup.

**Security note** : Set `cluster_ingress_cidr` to your
local host's public(or VPN) IP (in a '/32' CIDR notaion) in order to restrict access to
deployed services from outside. Use ``curl https://api.ipify.org`` to get the
public address value.

Then create a heat stack:
```
$ cd ~/traas
$ export OS_CLOUD=openstack
$ openstack stack create foo \
  -t templates/traas-oooq.yaml  \
  -e templates/traas-resource-registry.yaml \
  -e templates/example-environments/psi-env.yaml
```

Wait for provisioning ends, just watch for 'foo-undercloud login:' shown in
`openstack console log show foo-undercloud` outputs.

Prepare ansible inventory variables:

```
$ cd ~/oooq-warp
$ cp vars/undercloud-only-traas.yaml custom.yaml
$ #Or alternatively
$ export CUSTOMVARS=vars/undercloud-only-traas.yaml
```

Edit `vars/inventory-traas.yaml` with the PSI cloud creds used above.
Update `undercloud_network_cidr` and `undercloud_external_network_cidr`
in `vars/undercloud-networking.yaml` to correspond to the private networks and
subnets you created for your PSI cloud's tenant (traas expects the networks are
pre-created). Generate static inventory, SSH config and deploy:

```
$ TEAPSIWN=true \
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
