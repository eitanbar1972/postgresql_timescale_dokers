**Task status and resume instructions**

Purpose: record current progress and precise next steps so work can be resumed later.

Repository state

High-level TODO snapshot
High-level TODO snapshot
- Build Docker image: not-started
- Verify image exists locally: not-started
- Run container for Postgres (smoke test): not-started
- Run local container for Postgres: not-started
- Apply CNPG cluster manifest: not-started
- Port-forward CNPG primary: completed (local port 15432)
- Connect with pgAdmin: completed (pgAdmin on localhost:8080)
- Push to GitHub: completed
- Create manifests for two additional CNPG clusters: in-progress (started: 2026-08-11)
- Add TASKS.md describing steps to deploy and verify clusters: completed
- Apply new clusters to kind and verify readiness: not-started

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
  - `Build Docker image` (or `Run local container for Postgres`) depending on your priority.
Where to pick up next
- Primary in-progress task: `Create manifests for two additional CNPG clusters` — continue editing and add manifests for `timescaledb-cluster-2` and `timescaledb-cluster-3` under `kubernetes/`.
- After manifests are complete: run `kubectl apply -f kubernetes/cluster-timescaledb-2.yaml -n timescaledb` and `kubectl apply -f kubernetes/cluster-timescaledb-3.yaml -n timescaledb`.

Notes and safety
- Only one task is intentionally marked `in-progress` to preserve a clear single point of work for the agent.
- When that manifest work finishes, update this file to mark it `completed` and set the next task to `in-progress`.
- This file intentionally does NOT contain any plaintext secrets. Real credentials are in Kubernetes secrets in the `timescaledb` namespace.
- When resuming automated actions that require credentials (git push, docker push), ensure your local environment has proper auth configured.
