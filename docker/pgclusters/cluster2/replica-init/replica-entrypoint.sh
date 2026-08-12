#!/usr/bin/env bash
set -euo pipefail

export PGDATA="${PGDATA:-/var/lib/postgresql/data}"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  rm -rf "${PGDATA:?}"/*
  export PGPASSWORD="${REPLICATION_PASSWORD}"

  until pg_basebackup \
    -h "${PRIMARY_HOST}" \
    -D "$PGDATA" \
    -U "${REPLICATION_USER}" \
    -Fp \
    -Xs \
    -P \
    -R; do
    echo "Waiting for primary ${PRIMARY_HOST} to accept replication connections..."
    sleep 2
  done

  chmod 0700 "$PGDATA"
fi

exec docker-entrypoint.sh postgres
