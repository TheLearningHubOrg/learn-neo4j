// Stage 2 exercise: solutions. Run against the seeded starter graph:
//   cypher-shell -u neo4j -p <password> --file exercises/stage2.cypher
// The last statements remove everything this file adds.

// Step 1: the business key for reviews.
CREATE CONSTRAINT review_id IF NOT EXISTS
FOR (r:Review) REQUIRE r.id IS UNIQUE;

// Step 2: an idempotent load.
// MATCH the people and projects, MERGE only what the review adds.
UNWIND [
  {id: 'r1', who: 'bo', project: 'auth-service', score: 4},
  {id: 'r2', who: 'cy', project: 'graph-gateway', score: 5},
  {id: 'r3', who: 'ada', project: 'ingest-pipeline', score: 3}
] AS row
MATCH (p:Person {handle: row.who}), (pr:Project {slug: row.project})
MERGE (r:Review {id: row.id})
SET r.score = row.score
MERGE (p)-[:WROTE]->(r)
MERGE (r)-[:OF]->(pr);

// Step 3: exactly the same load again. Every MERGE matches, nothing is created.
UNWIND [
  {id: 'r1', who: 'bo', project: 'auth-service', score: 4},
  {id: 'r2', who: 'cy', project: 'graph-gateway', score: 5},
  {id: 'r3', who: 'ada', project: 'ingest-pipeline', score: 3}
] AS row
MATCH (p:Person {handle: row.who}), (pr:Project {slug: row.project})
MERGE (r:Review {id: row.id})
SET r.score = row.score
MERGE (p)-[:WROTE]->(r)
MERGE (r)-[:OF]->(pr);

MATCH (r:Review)
WITH count(r) AS reviews
MATCH ()-[x:WROTE|OF]->()
RETURN reviews, count(x) AS links;          // 3, 6 on every run

// Step 4: the constraint rejects a second r1, reported as data.
CALL () {
  CREATE (:Review {id: 'r1', score: 1})
} IN TRANSACTIONS ON ERROR CONTINUE REPORT STATUS AS s
RETURN s.committed AS committed, s.errorMessage AS error;

// Step 5: clean up so scripts/run-tests.sh passes again.
MATCH (r:Review) DETACH DELETE r;
DROP CONSTRAINT review_id IF EXISTS;
