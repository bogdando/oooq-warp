#!/bin/bash
set -ux
exec 2>/dev/null
if [ "${1:-sync}" = "sync" ]; then
  echo "Syncing state (only update with newer files) across known paths"
  for state in $STATE_ITEMS; do
    echo "Sync ${state} working_dir -> local_working_dir"
    rsync -qauxH $WORKSPACE/$state ${LWD}/
    echo "Sync ${state} image_cache_dir -> local_working_dir"
    rsync -qauxH $IMAGECACHE/$state ${LWD}/
    echo "Sync ${state} local_working_dir -> image_cache_dir"
    rsync -qauxH $LWD/$state ${IMAGECACHE}/
    echo "Sync ${state} local_working_dir -> working_dir"
    rsync -qauxH $LWD/$state ${WORKSPACE}/
  done
  chmod 600 ${LWD}/id_*
  chmod 600 ${WORKSPACE}/id_*
  chmod 600 ${IMAGECACHE}/id_*
else
  src=${1:-$LWD}
  echo "Saving state (with overwrite all) from ${src} to the known paths"
  for t in $(printf %"b\n" "${LWD}\n${WORKSPACE}\n${IMAGECACHE}"|sort -u); do
    [ "$src" = "$t" ] && continue
    for i in $STATE_ITEMS; do
      cp -f $src/$i ${t}/
    done
  done
fi
