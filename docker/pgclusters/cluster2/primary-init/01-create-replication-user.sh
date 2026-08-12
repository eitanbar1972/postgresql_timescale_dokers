#!/usr/bin/env bash
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${REPLICATION_USER}') THEN
    EXECUTE format(
      'CREATE ROLE %I WITH REPLICATION LOGIN PASSWORD %L',
      '${REPLICATION_USER}',
      '${REPLICATION_PASSWORD}'
    );
  END IF;
END
\$\$;
SQL

echo "host replication ${REPLICATION_USER} all scram-sha-256" >> "$PGDATA/pg_hba.conf"
