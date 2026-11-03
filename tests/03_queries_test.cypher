// 03_queries_test.cypher
// Exact answers for the Stage 3 queries over the seed data. The README shows
// each query in readable form; here each one is folded into a single test row.

// ---- recommendations ------------------------------------------------------------
// Friends of friends that ada does not follow yet, ranked by mutual friends.
MATCH (me:Person {handle: 'ada'})-[:FOLLOWS]->(friend:Person)-[:FOLLOWS]->(fof:Person)
WHERE fof <> me AND NOT (me)-[:FOLLOWS]->(fof)
WITH fof, count(DISTINCT friend) AS mutual
ORDER BY mutual DESC, fof.handle
WITH collect(fof.handle + ':' + mutual) AS got
RETURN 'friend-of-friend recommendations for ada' AS test,
       got = ['eli:2', 'dee:1', 'gus:1'] AS ok;

// People who know a skill the project uses but do not work on it yet.
MATCH (pr:Project {slug: 'ingest-pipeline'})-[:USES]->(:Skill)<-[:KNOWS]-(p:Person)
WHERE NOT (p)-[:WORKS_ON]->(pr)
WITH collect(DISTINCT p.handle) AS got
RETURN 'people who could join ingest-pipeline' AS test,
       coll.sort(got) = ['ada', 'hal'] AS ok;

// Relational division: people who know every skill auth-service uses.
MATCH (pr:Project {slug: 'auth-service'})
WITH COLLECT { MATCH (pr)-[:USES]->(s:Skill) RETURN s } AS needed
MATCH (p:Person)
WHERE all(s IN needed WHERE (p)-[:KNOWS]->(s))
WITH collect(p.handle) AS got
RETURN 'people who cover every auth-service skill' AS test,
       coll.sort(got) = ['bo', 'gus'] AS ok;

// ---- aggregation ----------------------------------------------------------------
MATCH (p:Person)-[:KNOWS]->(s:Skill)
WITH s.name AS skill, count(p) AS people
ORDER BY people DESC, skill
WITH collect(skill + ':' + people) AS got
RETURN 'people per skill, most common first' AS test,
       got = ['Cypher:3', 'Go:3', 'Python:3', 'Java:2', 'Kubernetes:2', 'Rust:2'] AS ok;

MATCH (:Person)-[k:KNOWS]->(:Skill {name: 'Cypher'})
RETURN 'average Cypher level is 4.0' AS test, avg(k.level) = 4.0 AS ok;

// OPTIONAL MATCH keeps projects with no match; count() of a null is 0.
MATCH (pr:Project)
OPTIONAL MATCH (pr)-[:USES]->(s:Skill)
WITH pr.slug AS slug, count(s) AS skills
ORDER BY slug
WITH collect(slug + ':' + skills) AS got
RETURN 'skills per project, including zero' AS test,
       got = ['auth-service:2', 'core-lib:1', 'graph-gateway:2', 'ingest-pipeline:2',
              'metrics-agent:1', 'ui-kit:0'] AS ok;

MATCH (p:Person)
WITH CASE WHEN p.joined < date('2022-01-01') THEN 'early' ELSE 'recent' END AS cohort,
     count(*) AS c
ORDER BY cohort
WITH collect(cohort + ':' + c) AS got
RETURN 'members bucketed by join date' AS test, got = ['early:3', 'recent:5'] AS ok;

// ---- subqueries -----------------------------------------------------------------
MATCH (p:Person)
WHERE COUNT { (p)-[:WORKS_ON]->(:Project) } >= 2
WITH collect(p.handle) AS got
RETURN 'COUNT subquery finds people on two or more projects' AS test,
       coll.sort(got) = ['ada', 'bo', 'hal'] AS ok;

MATCH (pr:Project {slug: 'graph-gateway'})
RETURN 'COLLECT subquery returns the team in start order' AS test,
       COLLECT { MATCH (p:Person)-[w:WORKS_ON]->(pr) RETURN p.handle ORDER BY w.since } = ['ada', 'bo', 'hal'] AS ok;

MATCH (a:Person), (b:Person)
WHERE a.city = b.city AND a.handle < b.handle
WITH collect([a.handle, b.handle]) AS got
RETURN 'pairs of people in the same city' AS test, got = [['ada', 'hal']] AS ok;

// ---- variable-length paths ------------------------------------------------------
MATCH (:Project {slug: 'graph-gateway'})-[:DEPENDS_ON]->+(dep:Project)
WITH collect(DISTINCT dep.slug) AS got
RETURN 'transitive dependencies of graph-gateway' AS test,
       coll.sort(got) = ['auth-service', 'core-lib', 'ui-kit'] AS ok;

MATCH p = (:Project {slug: 'graph-gateway'})-[:DEPENDS_ON]->+(:Project {slug: 'core-lib'})
RETURN 'two distinct dependency paths reach core-lib' AS test, count(p) = 2 AS ok;

MATCH (:Project {slug: 'graph-gateway'})-[:DEPENDS_ON]->+(d:Project)
WITH DISTINCT d
RETURN 'stars of the dependency closure, each project counted once' AS test,
       sum(d.stars) = 555 AS ok;

// The quantified pattern and the older *1.. syntax find the same dependents.
MATCH (d:Project)-[:DEPENDS_ON]->+(:Project {slug: 'core-lib'})
WITH count(DISTINCT d) AS qpp
MATCH (d2:Project)-[:DEPENDS_ON*1..]->(:Project {slug: 'core-lib'})
WITH qpp, count(DISTINCT d2) AS legacy
RETURN 'every other project depends on core-lib, both syntaxes agree' AS test,
       qpp = 5 AND legacy = 5 AS ok;

MATCH (:Project {slug: 'graph-gateway'})((a:Project)-[:DEPENDS_ON]->(b:Project) WHERE b.stars < a.stars){2}(leaf)
WITH collect(DISTINCT leaf.slug) AS got
RETURN 'quantified path pattern with a per-hop filter' AS test, got = ['core-lib'] AS ok;

// ---- shortest paths and cycles --------------------------------------------------
MATCH p = SHORTEST 1 (:Person {handle: 'ada'})-[:FOLLOWS]->+(:Person {handle: 'hal'})
RETURN 'shortest follow chain from ada to hal' AS test,
       [n IN nodes(p) | n.handle] = ['ada', 'cy', 'gus', 'hal'] AS ok;

MATCH p = shortestPath((:Person {handle: 'ada'})-[:FOLLOWS*]->(:Person {handle: 'hal'}))
RETURN 'legacy shortestPath() agrees on the length' AS test, length(p) = 3 AS ok;

// A path pattern never repeats a relationship (trail semantics), but it may
// pass through the start node again: two short cycles chain into a long one.
MATCH p = (a:Person {handle: 'ada'})-[:FOLLOWS]->+(a)
WITH min(length(p)) AS shortest, count(p) AS cycles
RETURN 'cycles through ada: shortest has 3 hops, 8 trails in total' AS test,
       shortest = 3 AND cycles = 8 AS ok;

// ---- indexes in use -------------------------------------------------------------
MATCH ()-[w:WORKS_ON]->()
WHERE w.since >= 2023
RETURN 'relationship range filter on WORKS_ON.since' AS test, count(w) = 5 AS ok;

MATCH (p:Project)
WHERE p.name CONTAINS 'Service'
WITH collect(p.slug) AS got
RETURN 'CONTAINS on a text-indexed property' AS test, got = ['auth-service'] AS ok;

CALL db.index.fulltext.queryNodes('project_search', 'graph') YIELD node
WITH collect(node.slug) AS got
RETURN 'full-text search matches name and description' AS test,
       coll.sort(got) = ['graph-gateway', 'ingest-pipeline'] AS ok;

// ---- Cypher 25 clauses ----------------------------------------------------------
CYPHER 25
MATCH (p:Person)-[k:KNOWS]->(:Skill {name: 'Cypher'})
FILTER k.level >= 4
LET tag = p.handle + '@' + k.level
WITH collect(tag) AS got
RETURN 'FILTER and LET (Cypher 25)' AS test, coll.sort(got) = ['ada@5', 'hal@4'] AS ok;
