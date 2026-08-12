**Task status and resume instructions**

Purpose: record current progress and precise next steps so work can be resumed later.

Repository state

High-level TODO snapshot
- Build Docker image: not-started
- Verify image exists locally: not-started
- Run container for Postgres (smoke test): not-started
- Run local container for Postgres: completed (docker-compose clusters started)
- Apply CNPG cluster manifest: not-started
- Port-forward CNPG primary: completed (local port 15432)
- Connect with pgAdmin: completed (pgAdmin on localhost:8080)
- Push to GitHub: completed
- Create manifests for two additional CNPG clusters: deferred
- Create manifests for two additional CNPG clusters: completed (2026-08-11)
- Add TASKS.md describing steps to deploy and verify clusters: completed
- Apply new clusters to kind and verify readiness: completed (2026-08-11)
- Deploy Prometheus and Grafana monitoring for all CNPG clusters: in-progress (2026-08-11)

Active resources
  - CNPG primary svc `timescaledb-cluster-rw` -> localhost:15432
  - pgAdmin svc `timescaledb-cluster-pgadmin4` -> localhost:8080

How to resume locally (commands)
1. Pull latest repo and confirm branch:
```
git fetch origin
git checkout main
git pull
```
2. If you want to rebuild Grafana image (optional):
```
docker build -t grafana-cnpg:local -f docker/grafana/Dockerfile docker/grafana
```
3. To build the Postgres image (may take long):
```
docker build -t timescaledb-cnpg-vector:local -f docker/Dockerfile .
```
4. To apply the CNPG cluster manifest to `kind` (ensure `kubectl` context is `kind-kind`):
```
kubectl config use-context kind-kind
kubectl apply -f kubernetes/cluster-timescaledb.yaml -n timescaledb
```
5. To restore port-forwards (run in separate terminals):
```
kubectl port-forward svc/timescaledb-cluster-rw 15432:5432 -n timescaledb
kubectl port-forward svc/timescaledb-cluster-pgadmin4 8080:80 -n timescaledb
```

Where to pick up next
- Primary next task: finish monitoring rollout verification after Grafana and the Prometheus operator complete their initial image pulls in the `monitoring` namespace.
- Secondary next task: build the custom TimescaleDB/CNPG operand image only if you want to replace placeholder image references in the repo manifests.

Update: user requested two ordinary PostgreSQL Docker clusters (not CNPG). Created and verified two Docker Compose stacks under `docker/pgclusters/cluster1` and `docker/pgclusters/cluster2` using the official `postgres:17` image with primary/replica replication bootstrap scripts.

Next steps for these stacks:
- Cluster1 is running: `docker compose -f docker/pgclusters/cluster1/docker-compose.yml up -d`
- Cluster2 is running: `docker compose -f docker/pgclusters/cluster2/docker-compose.yml up -d`
- Connect with psql: `psql -h localhost -p 55432 -U postgres` (Cluster1) or `-p 55433` (Cluster2).
- Replicas verified: `pg1-replica` and `pg2-replica` both returned `pg_is_in_recovery() = true` on 2026-08-11.

Current verified runtime state on 2026-08-11
- Docker containers running: `pg1-primary`, `pg1-replica`, `pg2-primary`, `pg2-replica`, and existing `timescaledb`.
- Host ports: Cluster1 primary on `localhost:55432`, Cluster2 primary on `localhost:55433`, existing TimescaleDB on `localhost:5433`.
- Kubernetes CNPG clusters in namespace `default` are healthy:
  - `timescaledb-cluster` -> `READY 2/2`
  - `postgresql-cluster-1` -> `READY 2/2`
  - `postgresql-cluster-2` -> `READY 2/2`
- Added manifests:
  - `kubernetes/cluster-postgresql-cnpg.yaml` for the two regular PostgreSQL CNPG clusters using the official `ghcr.io/cloudnative-pg/postgresql:17.6-system-trixie` image catalog.
  - `kubernetes/monitoring-namespace.yaml`
  - updated `kubernetes/cnpg-monitoring.yaml`
  - updated `kubernetes/grafana-dashboards-configmap.yaml`
  - updated `kubernetes/monitoring-values.yaml`
- Monitoring namespace resources now exist:
  - Services: `monitoring-grafana`, `monitoring-kube-prometheus-prometheus`, `monitoring-kube-prometheus-operator`, `monitoring-kube-prometheus-alertmanager`
  - PodMonitors: `timescaledb-cluster`, `postgresql-cluster-1`, `postgresql-cluster-2`, `cnpg-controller-manager`
  - PrometheusRule: `cnpg-cluster-alerts`
- Monitoring rollout status at handoff:
  - `kube-prometheus-stack` Helm release `monitoring` is `deployed`
  - `monitoring-kube-state-metrics` and `monitoring-prometheus-node-exporter` are running
  - Grafana and the Prometheus operator were still completing initial image pulls when work paused
- Note: no repository `TODO` file was present when resuming work; only `TASK_STATUS.md` was found.

Notes and safety
- Only one task is intentionally marked `in-progress` to preserve a clear single point of work for the agent.
- When that manifest work finishes, update this file to mark it `completed` and set the next task to `in-progress`.
- This file intentionally does NOT contain any plaintext secrets. Real credentials are in Kubernetes secrets in the `timescaledb` namespace.
- When resuming automated actions that require credentials (git push, docker push), ensure your local environment has proper auth configured.
