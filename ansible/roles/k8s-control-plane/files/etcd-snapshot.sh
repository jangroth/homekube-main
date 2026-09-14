#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/lib/etcd-backups"
SNAPSHOT="${BACKUP_DIR}/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db"
RETAIN_DAYS=14

mkdir -p "${BACKUP_DIR}"

ETCDCTL_API=3 etcdctl snapshot save "${SNAPSHOT}" \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key

# Verify the snapshot is valid
ETCDCTL_API=3 etcdctl snapshot status "${SNAPSHOT}" --write-out=table

# Purge snapshots older than retention window
find "${BACKUP_DIR}" -name 'etcd-snapshot-*.db' -mtime "+${RETAIN_DAYS}" -delete

echo "etcd snapshot saved to ${SNAPSHOT}"
