#!/usr/bin/env bash
# Loads cypher/NN_*.cypher into an empty Neo4j database, then runs every
# tests/NN_*_test.cypher through cypher-shell.
#
# Each test statement returns one row with the columns test and ok, and ends
# with "AS ok;". The runner counts those endings per file, so a statement that
# returns no row fails just like one that returns FALSE.
#
#   NEO4J_PASSWORD=secret123 bash scripts/run-tests.sh
#   NEO4J_ADDRESS=neo4j://db:7687 NEO4J_USERNAME=neo4j NEO4J_PASSWORD=... bash scripts/run-tests.sh
#
# The database must be empty. RESET=1 deletes every node and relationship
# first; never point that at a database you care about.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${NEO4J_ADDRESS:=neo4j://localhost:7687}"
: "${NEO4J_USERNAME:=neo4j}"
: "${NEO4J_PASSWORD:?set NEO4J_PASSWORD}"
: "${NEO4J_DATABASE:=neo4j}"
# cypher-shell reads the credentials from the environment, which keeps the
# password out of the process list.
export NEO4J_USERNAME NEO4J_PASSWORD

cypher() {
  cypher-shell --address "$NEO4J_ADDRESS" --database "$NEO4J_DATABASE" \
    --format plain --non-interactive "$@"
}

nodes="$(cypher 'MATCH (n) RETURN count(n) AS nodes' | tail -n 1)"
if [[ "$nodes" != 0 ]]; then
  if [[ -z "${RESET:-}" ]]; then
    echo "database ${NEO4J_DATABASE} holds ${nodes} nodes; set RESET=1 to wipe it" >&2
    exit 2
  fi
  echo "== RESET=1: deleting ${nodes} nodes"
  cypher 'MATCH (n) CALL (n) { DETACH DELETE n } IN TRANSACTIONS OF 1000 ROWS'
fi

for file in cypher/[0-9][0-9]_*.cypher; do
  echo "== apply ${file}"
  cypher --file "$file"
done

passed=0
failed=0
for test in tests/[0-9][0-9]_*_test.cypher; do
  echo "== ${test}"
  expected="$(grep -c 'AS ok;$' "$test")"
  if ! output="$(cypher --file "$test" 2>&1)"; then
    printf '%s\n' "$output" >&2
    echo "FAIL ${test}: cypher-shell stopped on an error" >&2
    failed=$((failed + 1))
    continue
  fi
  seen=0
  while IFS= read -r line; do
    case "$line" in
      '' | 'test, ok') ;;
      *', TRUE')
        seen=$((seen + 1)); passed=$((passed + 1))
        label="${line%, TRUE}"; echo "ok   ${label//\"/}" ;;
      *)
        seen=$((seen + 1)); failed=$((failed + 1))
        echo "FAIL ${line}" >&2 ;;
    esac
  done <<< "$output"
  if [[ "$seen" -ne "$expected" ]]; then
    echo "FAIL ${test}: ${expected} test statements, ${seen} result rows" >&2
    failed=$((failed + 1))
  fi
done

echo "${passed} passed, ${failed} failed"
[[ "$failed" -eq 0 ]]
