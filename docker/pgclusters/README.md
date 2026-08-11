PostgreSQL Docker clusters (local)

This folder contains two small Docker Compose stacks that bring up simple PostgreSQL clusters (primary + replica) for local testing.

Cluster 1
- Compose file: `docker/pgclusters/cluster1/docker-compose.yml`
- Primary exposed on host port `55432` (connect with `psql -h localhost -p 55432 -U postgres`)
- Default superuser password: `ChangeMe1`
- Replication user: `repl_user` / `repl_pass1`

Cluster 2
- Compose file: `docker/pgclusters/cluster2/docker-compose.yml`
- Primary exposed on host port `55433` (connect with `psql -h localhost -p 55433 -U postgres`)
- Default superuser password: `ChangeMe2`
- Replication user: `repl_user` / `repl_pass2`

Start a cluster (from repo root):

```bash
docker compose -f docker/pgclusters/cluster1/docker-compose.yml up -d
docker compose -f docker/pgclusters/cluster2/docker-compose.yml up -d
```

Stop and remove:

```bash
docker compose -f docker/pgclusters/cluster1/docker-compose.yml down
docker compose -f docker/pgclusters/cluster2/docker-compose.yml down
```

Notes:
- These stacks use `bitnami/postgresql:17` which supports simple master/replica bootstrapping via environment variables.
- Adjust ports, passwords, and volumes as needed. For production use, secure secrets and persistent storage appropriately.
