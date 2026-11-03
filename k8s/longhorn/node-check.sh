#!/usr/bin/env bash
set -euo pipefail
# Read-only host preflight. Run once on EACH of the 3 storage nodes.
for cmd in lsblk findmnt blkid mountpoint iscsiadm systemctl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then echo "MISSING: $cmd"; fi
done
printf '\n--- Host ---\n'; hostnamectl --static
printf '\n--- Block devices ---\n'; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,UUID
printf '\n--- Longhorn mount ---\n'
if mountpoint -q /var/lib/longhorn; then
  findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS /var/lib/longhorn
  df -hT /var/lib/longhorn
else
  echo 'ERROR: /var/lib/longhorn is not a standalone mount point' >&2
  exit 1
fi
printf '\n--- iSCSI ---\n'; systemctl is-active iscsid || true
printf '\n--- kernel ---\n'; uname -r
printf '\n--- time ---\n'; timedatectl status | head -n 12
