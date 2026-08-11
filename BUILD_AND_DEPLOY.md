# Build and deploy PostgreSQL 17 + TimescaleDB + maintenance extensions

The Docker image contains the database binaries and extension artifacts. Prometheus
and Grafana run as separate Kubernetes workloads and scrape CloudNativePG's built-in
metrics endpoint; no `postgres_exporter` sidecar is required.

## 1. Prerequisites

- Docker Desktop or Docker Engine with BuildKit/buildx.
- Kubernetes or k3s with CloudNativePG already installed.
- Helm 3 for Prometheus and Grafana.

## 2. Build and push the image

PowerShell:

```powershell
$Image = "your-registry.example.com/data/cnpg-timescale-observability:pg17"

docker buildx build `
  --platform linux/amd64 `
  --pull `
  --progress=plain `
  --load `
  -t $Image `
  -f docker/Dockerfile `
  .

docker login your-registry.example.com
docker push $Image
```

## 3. Deploy the CloudNativePG cluster

Edit [kubernetes/cluster-timescaledb.yaml](kubernetes/cluster-timescaledb.yaml) and replace the placeholder image reference with the image you pushed.

Apply it:

```bash
kubectl apply -f kubernetes/cluster-timescaledb.yaml
kubectl -n timescaledb get pods -w
```

## 4. Install Prometheus, Grafana, and Alertmanager

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values kubernetes/monitoring-values.yaml
```

Apply the monitoring rules:

```bash
kubectl apply -f kubernetes/cnpg-monitoring.yaml
```

## 5. Smoke tests

```bash
./cluster-setup.sh
./initialize-db.sh
./run-capability-tests.sh
```
