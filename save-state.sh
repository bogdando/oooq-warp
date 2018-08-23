#!/bin/bash
set -u
exec 2>/dev/null
STATE_ITEMS="
id_*
ironic*
hosts
ssh.*
overcloud*
ironic*
*.tar*
*.qcow2*
undercloud*
volume_pool.xml
instackenv.json
"

cmd=${1:---sync}
if [ "${cmd}" = "--sync" ]; then
  echo "Syncing state (only update with newer files) across known paths"
  for state in $STATE_ITEMS; do
    if [ "$WORKSPACE" != "$LWD" ]; then
      echo "Sync ${state} working_dir -> local_working_dir"
      rsync -qauxH $WORKSPACE/$state ${LWD}/
    fi
    if [ "$IMAGECACHE" != "$LWD" ]; then
      echo "Sync ${state} image_cache_dir -> local_working_dir"
      rsync -qauxH $IMAGECACHE/$state ${LWD}/
      echo "Sync ${state} local_working_dir -> image_cache_dir"
      rsync -qauxH $LWD/$state ${IMAGECACHE}/
    fi
    if [ "$WORKSPACE" != "$LWD" ]; then
      echo "Sync ${state} local_working_dir -> working_dir"
      rsync -qauxH $LWD/$state ${WORKSPACE}/
    fi
  done
  chmod 600 ${LWD}/id_*
  chmod 600 ${WORKSPACE}/id_*
  chmod 600 ${IMAGECACHE}/id_*
elif [ "${cmd}" = "--purge" ]; then
  echo "Purging all saved state from the known paths"
  for p in $KNOWN_PATHS; do
    for i in $STATE_ITEMS; do
      echo "Removing $p/$i"
      rm -f $p/$i
    done
  done
  rm -rf $LWD/ansible_facts_cache/ /tmp/ansible_facts_cache
else
  src=${1:-$LWD}
  echo "Saving state (with overwrite all) from ${src} to the known paths"
  for p in $KNOWN_PATHS; do
    [ "$src" = "$p" ] && continue
    for i in $STATE_ITEMS; do
      echo "Copying $src/$i to $p"
      cp -f $src/$i ${p}/
    done
  done
fi
if [ "${cmd}" = "--purge" ]; then
  echo "!!! REMEMBER TO CLEAN UP THE HOST'S /home/$USER/.ssh/authorized_keys !!!"
  cat ${LWD}/id_rsa_virt_power.pub 2>/dev/null
  cat ${LWD}/id_rsa_virt_host.pub 2>/dev/null
else
  echo "!!! REMEMBER TO ADD THE HOST'S /home/$USER/.ssh/authorized_keys !!!"
  cat ${LWD}/id_rsa_virt_power.pub 2>/dev/null
  cat ${LWD}/id_rsa_virt_host.pub 2>/dev/null
fi
