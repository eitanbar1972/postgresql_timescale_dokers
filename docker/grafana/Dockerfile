FROM grafana/grafana:9.5.0

USER root

# Copy provisioning files into image so Grafana auto-provisions datasource and dashboards
COPY provisioning /etc/grafana/provisioning
COPY dashboards /var/lib/grafana/dashboards

RUN chown -R grafana:grafana /etc/grafana/provisioning /var/lib/grafana/dashboards

USER grafana

ENV GF_PATHS_PROVISIONING=/etc/grafana/provisioning

LABEL org.opencontainers.image.title="Grafana with CloudNativePG dashboard"
