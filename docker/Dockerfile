# syntax=docker/dockerfile:1.7

# =============================================================================
# CloudNativePG PostgreSQL image (Debian Bookworm)
#
# Extensions:
#   - TimescaleDB
#   - TimescaleDB Toolkit
#   - pgvector
#   - pgvectorscale
#   - pg_cron
#   - pg_stat_statements and auto_explain
#   - amcheck, pgstattuple, pg_buffercache, pg_visibility
#   - pg_freespacemap, pg_prewarm, and pageinspect
#   - pg_repack, hypopg, pgaudit, pg_stat_kcache, pg_qualstats
#   - pg_partman
# =============================================================================

ARG PG_MAJOR=17
ARG PGVECTOR_VERSION=0.8.1
ARG PGVECTORSCALE_VERSION=0.9.0
ARG RUST_VERSION=1.91
ARG PGRX_VERSION=0.16.1

# STAGE 1: Build pgvector (C extension)
FROM ghcr.io/cloudnative-pg/postgresql:${PG_MAJOR}-bookworm AS pgvector-builder

ARG PG_MAJOR
ARG PGVECTOR_VERSION

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        gnupg \
        lsb-release; \
    install -d -m 0755 /usr/share/keyrings; \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        | gpg --dearmor -o /usr/share/keyrings/postgresql-pgdg.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-pgdg.gpg] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends postgresql-server-dev-${PG_MAJOR}; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN git clone \
        --branch v${PGVECTOR_VERSION} \
        --depth 1 \
        https://github.com/pgvector/pgvector.git

WORKDIR /tmp/pgvector

RUN make clean \
    && make OPTFLAGS="" \
    && make install

# STAGE 2: Build pgvectorscale (Rust extension)
FROM rust:${RUST_VERSION}-bookworm AS pgvectorscale-builder

ARG PG_MAJOR
ARG PGVECTORSCALE_VERSION
ARG PGRX_VERSION

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        clang \
        curl \
        git \
        gnupg \
        lsb-release \
        libssl-dev \
        pkg-config; \
    install -d -m 0755 /usr/share/keyrings; \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        | gpg --dearmor -o /usr/share/keyrings/postgresql-pgdg.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-pgdg.gpg] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        postgresql-${PG_MAJOR} \
        postgresql-server-dev-${PG_MAJOR}; \
    rm -rf /var/lib/apt/lists/*

RUN cargo install --locked cargo-pgrx --version ${PGRX_VERSION}

RUN cargo pgrx init --pg${PG_MAJOR} /usr/bin/pg_config

WORKDIR /tmp

RUN git clone \
        --branch ${PGVECTORSCALE_VERSION} \
        --depth 1 \
        https://github.com/timescale/pgvectorscale.git

WORKDIR /tmp/pgvectorscale/pgvectorscale

ENV RUSTFLAGS="-C target-cpu=x86-64-v3 -C target-feature=+avx2,+fma"

RUN cargo pgrx install --pg-config /usr/bin/pg_config

# STAGE 3: Install packaged PostgreSQL extensions and maintenance tools
FROM ghcr.io/cloudnative-pg/postgresql:${PG_MAJOR}-bookworm AS packaged-extensions

ARG PG_MAJOR

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release; \
    install -d -m 0755 /usr/share/keyrings; \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        | gpg --dearmor -o /usr/share/keyrings/postgresql-pgdg.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-pgdg.gpg] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list; \
    curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
        | gpg --dearmor -o /usr/share/keyrings/timescaledb.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/timescaledb.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        timescaledb-2-postgresql-${PG_MAJOR} \
        timescaledb-toolkit-postgresql-${PG_MAJOR} \
        postgresql-${PG_MAJOR} \
        postgresql-${PG_MAJOR}-cron \
        postgresql-${PG_MAJOR}-hypopg \
        postgresql-${PG_MAJOR}-partman \
        postgresql-${PG_MAJOR}-pgaudit \
        postgresql-${PG_MAJOR}-pg-qualstats \
        postgresql-${PG_MAJOR}-pg-stat-kcache \
        postgresql-${PG_MAJOR}-repack; \
    rm -rf /var/lib/apt/lists/*

# STAGE 4: Assemble the final lean CloudNativePG image
FROM ghcr.io/cloudnative-pg/postgresql:${PG_MAJOR}-bookworm

ARG PG_MAJOR

USER root

COPY --from=pgvector-builder \
    /usr/lib/postgresql/${PG_MAJOR}/lib/vector.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=pgvector-builder \
    /usr/share/postgresql/${PG_MAJOR}/extension/vector*.sql \
    /usr/share/postgresql/${PG_MAJOR}/extension/
COPY --from=pgvector-builder \
    /usr/share/postgresql/${PG_MAJOR}/extension/vector.control \
    /usr/share/postgresql/${PG_MAJOR}/extension/

COPY --from=pgvectorscale-builder \
    /usr/lib/postgresql/${PG_MAJOR}/lib/vectorscale-*.so* \
    /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=pgvectorscale-builder \
    /usr/share/postgresql/${PG_MAJOR}/extension/vectorscale*.sql \
    /usr/share/postgresql/${PG_MAJOR}/extension/
COPY --from=pgvectorscale-builder \
    /usr/share/postgresql/${PG_MAJOR}/extension/vectorscale.control \
    /usr/share/postgresql/${PG_MAJOR}/extension/

COPY --from=packaged-extensions \
    /usr/lib/postgresql/${PG_MAJOR}/lib/timescaledb*.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=packaged-extensions \
    /usr/share/postgresql/${PG_MAJOR}/extension/timescaledb*.sql \
    /usr/share/postgresql/${PG_MAJOR}/extension/
COPY --from=packaged-extensions \
    /usr/share/postgresql/${PG_MAJOR}/extension/timescaledb.control \
    /usr/share/postgresql/${PG_MAJOR}/extension/

COPY --from=packaged-extensions \
    /usr/lib/postgresql/${PG_MAJOR}/lib/timescaledb_toolkit-*.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=packaged-extensions \
    /usr/share/postgresql/${PG_MAJOR}/extension/timescaledb_toolkit*.sql \
    /usr/share/postgresql/${PG_MAJOR}/extension/
COPY --from=packaged-extensions \
    /usr/share/postgresql/${PG_MAJOR}/extension/timescaledb_toolkit.control \
    /usr/share/postgresql/${PG_MAJOR}/extension/

COPY --from=packaged-extensions \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pg_cron.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=packaged-extensions \
    /usr/share/postgresql/${PG_MAJOR}/extension/pg_cron*.sql \
    /usr/share/postgresql/${PG_MAJOR}/extension/
COPY --from=packaged-extensions \
    /usr/share/postgresql/${PG_MAJOR}/extension/pg_cron.control \
    /usr/share/postgresql/${PG_MAJOR}/extension/

COPY --from=packaged-extensions \
    /usr/lib/postgresql/${PG_MAJOR}/lib/amcheck.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/auto_explain.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pageinspect.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pg_buffercache.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pg_freespacemap.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pg_prewarm.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pg_stat_statements.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pg_visibility.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pgstattuple.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=packaged-extensions \
    /usr/share/postgresql/${PG_MAJOR}/extension/amcheck* \
    /usr/share/postgresql/${PG_MAJOR}/extension/pageinspect* \
    /usr/share/postgresql/${PG_MAJOR}/extension/pg_buffercache* \
    /usr/share/postgresql/${PG_MAJOR}/extension/pg_freespacemap* \
    /usr/share/postgresql/${PG_MAJOR}/extension/pg_prewarm* \
    /usr/share/postgresql/${PG_MAJOR}/extension/pg_stat_statements* \
    /usr/share/postgresql/${PG_MAJOR}/extension/pg_visibility* \
    /usr/share/postgresql/${PG_MAJOR}/extension/pgstattuple* \
    /usr/share/postgresql/${PG_MAJOR}/extension/

COPY --from=packaged-extensions \
    /usr/lib/postgresql/${PG_MAJOR}/lib/hypopg.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pgaudit.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pg_partman_bgw.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pg_qualstats.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pg_repack.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/pg_stat_kcache.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=packaged-extensions \
    /usr/share/postgresql/${PG_MAJOR}/extension/hypopg* \
    /usr/share/postgresql/${PG_MAJOR}/extension/pgaudit* \
    /usr/share/postgresql/${PG_MAJOR}/extension/pg_partman* \
    /usr/share/postgresql/${PG_MAJOR}/extension/pg_qualstats* \
    /usr/share/postgresql/${PG_MAJOR}/extension/pg_repack* \
    /usr/share/postgresql/${PG_MAJOR}/extension/pg_stat_kcache* \
    /usr/share/postgresql/${PG_MAJOR}/extension/
COPY --from=packaged-extensions \
    /usr/lib/postgresql/${PG_MAJOR}/bin/pg_repack \
    /usr/lib/postgresql/${PG_MAJOR}/bin/

RUN set -eux; \
    test -f /usr/lib/postgresql/${PG_MAJOR}/lib/pg_stat_statements.so; \
    test -f /usr/lib/postgresql/${PG_MAJOR}/lib/auto_explain.so; \
    test -f /usr/lib/postgresql/${PG_MAJOR}/lib/pg_cron.so; \
    test -f /usr/lib/postgresql/${PG_MAJOR}/lib/pg_repack.so; \
    test -x /usr/lib/postgresql/${PG_MAJOR}/bin/pg_repack; \
    test -f /usr/share/postgresql/${PG_MAJOR}/extension/timescaledb_toolkit.control; \
    test -f /usr/share/postgresql/${PG_MAJOR}/extension/pg_partman.control

USER 26

LABEL org.opencontainers.image.title="CloudNativePG TimescaleDB, vector, maintenance, and observability image"
LABEL org.opencontainers.image.description="PostgreSQL ${PG_MAJOR} with TimescaleDB, vector search, pg_cron, performance, audit, bloat, integrity, and partition-management extensions"
LABEL org.opencontainers.image.source="https://github.com/your-org/your-repo"
