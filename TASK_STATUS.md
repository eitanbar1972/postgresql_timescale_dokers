**Task status and resume instructions**

Purpose: record current progress and precise next steps so work can be resumed later.

Repository state
- Branch: main
- Last pushed commit: aa1ca6c (Grafana provisioning + pgaudit edits)

High-level TODO snapshot
- Build Docker image: in-progress
- Run local container for Postgres: not-started
- Apply CNPG cluster manifest: not-started
- Port-forward CNPG primary: completed (local port 15432)
- Connect with pgAdmin: completed (pgAdmin on localhost:8080)
- Push to GitHub: completed

Active resources
- Kubernetes context used previously: `kind-kind` (default namespace `timescaledb`)
- Port-forwards started (local):
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
- If token/agent stops: reopen this repo, confirm `TASK_STATUS.md`, then continue at the first unfinished TODO:
  - `Build Docker image` (or `Run local container for Postgres`) depending on your priority.

Notes and safety
- This file intentionally does NOT contain any plaintext secrets. Real credentials are in Kubernetes secrets in the `timescaledb` namespace.
- When resuming automated actions that require credentials (git push, docker push), ensure your local environment has proper auth configured.

Generated: 2026-08-11
