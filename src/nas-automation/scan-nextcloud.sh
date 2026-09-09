#!/bin/bash
# Rescans the Local external storage mounts so changes made outside Nextcloud
# (Local storage backend has no active change notifications) show up.
# flock ensures only one instance runs at a time, since a full scan can take
# longer than the hourly cron interval.
exec 200>/tmp/nextcloud-scan.lock
chmod 666 /tmp/nextcloud-scan.lock 2>/dev/null
flock -n 200 || exit 0

mount_ids=$(sudo docker exec -u www-data nextcloud-app php occ files_external:list --all --output=json \
  | jq -r '.[].mount_id')

for id in $mount_ids; do
  sudo docker exec -u www-data nextcloud-app php occ files_external:scan "$id"
done
