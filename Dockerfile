# syntax=docker/dockerfile:1
# Two stages:
#   verify  - starts a throwaway Neo4j inside the build, loads cypher/ and runs
#             tests/. A failing test fails the image build. The seeded store is
#             kept for the next stage.
#   runtime - the official image with the seeded "neo4j" database copied into
#             /data, running as the unprivileged neo4j user.
ARG NEO4J_IMAGE=neo4j:2026.10-community

# ---- verify -----------------------------------------------------------------
FROM ${NEO4J_IMAGE} AS verify
RUN install -d -o neo4j -g neo4j /work /work/data
COPY --chown=neo4j:neo4j cypher/ /work/cypher/
COPY --chown=neo4j:neo4j tests/ /work/tests/
COPY --chown=neo4j:neo4j scripts/ /work/scripts/
USER neo4j
# The image's entrypoint normally points the data directory at the /data
# volume; outside the entrypoint we set it ourselves, to a path that is not a
# volume, so the next stage can copy the store out of this one.
# The password is a throwaway for this stage only: it lives in the system
# database, which the runtime stage does not copy.
RUN export NEO4J_PASSWORD=build-only-password \
 && printf '%s\n' 'server.directories.data=/work/data' >> conf/neo4j.conf \
 && neo4j-admin dbms set-initial-password "$NEO4J_PASSWORD" \
 && neo4j start \
 && for _ in $(seq 1 90); do \
      cypher-shell -u neo4j -p "$NEO4J_PASSWORD" 'RETURN 1' >/dev/null 2>&1 && break; sleep 1; \
    done \
 && bash /work/scripts/run-tests.sh \
 && neo4j stop

# ---- runtime ----------------------------------------------------------------
FROM ${NEO4J_IMAGE} AS runtime
# Only the user database is copied. The system database (users, roles, the
# password) is created on first start from NEO4J_AUTH, so no build secret ships.
COPY --from=verify --chown=neo4j:neo4j /work/data/databases/neo4j /data/databases/neo4j
COPY --from=verify --chown=neo4j:neo4j /work/data/transactions/neo4j /data/transactions/neo4j
COPY --chown=neo4j:neo4j cypher/ /seed/
# The official entrypoint supports a non-root user and skips its chown steps.
USER neo4j
# 7474 is HTTP (Query API, health), 7687 is Bolt for drivers and cypher-shell.
EXPOSE 7474 7687
HEALTHCHECK --interval=5s --timeout=3s --start-period=20s --retries=24 \
  CMD wget -q --spider http://127.0.0.1:7474/ || exit 1
