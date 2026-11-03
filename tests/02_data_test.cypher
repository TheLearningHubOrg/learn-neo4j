// 02_data_test.cypher
// The seed has the expected shape, MERGE is idempotent and the constraints
// reject duplicates. Failing writes run inside CALL { } IN TRANSACTIONS with
// ON ERROR CONTINUE, which reports the error as data instead of aborting.

// ---- shape -------------------------------------------------------------------
MATCH (n)
WITH labels(n)[0] AS label, count(*) AS c ORDER BY label
WITH collect(label + '=' + c) AS got
RETURN 'node counts per label' AS test,
       got = ['Person=8', 'Project=6', 'Skill=6'] AS ok;

MATCH ()-[r]->()
WITH type(r) AS t, count(*) AS c ORDER BY t
WITH collect(t + '=' + c) AS got
RETURN 'relationship counts per type' AS test,
       got = ['DEPENDS_ON=7', 'FOLLOWS=11', 'KNOWS=15', 'USES=8', 'WORKS_ON=11'] AS ok;

MATCH (p:Person)
WITH collect(p.joined IS :: DATE NOT NULL) AS checks
RETURN 'every Person.joined is a DATE, not a string' AS test,
       all(c IN checks WHERE c) AS ok;

MATCH (:Person)-[k:KNOWS]->(:Skill)
WITH min(k.level) AS lo, max(k.level) AS hi
RETURN 'skill levels stay between 1 and 5' AS test, lo >= 1 AND hi <= 5 AS ok;

MATCH (p:Project) WHERE NOT (p)-[:USES]->(:Skill)
WITH collect(p.slug) AS idle
RETURN 'only ui-kit uses no tracked skill' AS test, idle = ['ui-kit'] AS ok;

// ---- MERGE is idempotent -------------------------------------------------------
MERGE (p:Person {handle: 'ada'})
WITH count(p) AS merged
MATCH (everyone:Person)
WITH merged, count(everyone) AS people
RETURN 'MERGE on an existing key matches instead of creating' AS test,
       merged = 1 AND people = 8 AS ok;

MATCH (a:Person {handle: 'ada'}), (b:Person {handle: 'bo'})
MERGE (a)-[:FOLLOWS]->(b)
WITH a, b
MATCH (a)-[f:FOLLOWS]->(b)
RETURN 'MERGE does not duplicate an existing relationship' AS test, count(f) = 1 AS ok;

// ---- constraints reject duplicates ---------------------------------------------
CALL () {
  CREATE (:Person {handle: 'ada', name: 'Second Ada'})
} IN TRANSACTIONS ON ERROR CONTINUE REPORT STATUS AS s
RETURN 'duplicate Person.handle is rejected' AS test,
       s.committed = false AND s.errorMessage CONTAINS 'already exists' AS ok;

CALL () {
  CREATE (:Skill {name: 'Go'})
} IN TRANSACTIONS ON ERROR CONTINUE REPORT STATUS AS s
RETURN 'duplicate Skill.name is rejected' AS test,
       s.committed = false AND s.errorMessage CONTAINS 'already exists' AS ok;

CALL () {
  MATCH (p:Project {slug: 'ui-kit'})
  SET p.slug = 'core-lib'
} IN TRANSACTIONS ON ERROR CONTINUE REPORT STATUS AS s
RETURN 'renaming a slug onto an existing one is rejected' AS test,
       s.committed = false AND s.errorMessage CONTAINS 'already exists' AS ok;

MATCH (p:Person {handle: 'ada'})
RETURN 'the failed writes left the original row untouched' AS test,
       count(p) = 1 AND min(p.name) = 'Ada Okafor' AS ok;

// Uniqueness is case-sensitive: 'Ada' is a different value from 'ada'.
// Normalise keys before you write them (see Stage 2).
CALL () {
  CREATE (x:Person {handle: 'ADA'})
  DELETE x
} IN TRANSACTIONS ON ERROR CONTINUE REPORT STATUS AS s
RETURN 'uniqueness is case-sensitive' AS test, s.committed AS ok;
