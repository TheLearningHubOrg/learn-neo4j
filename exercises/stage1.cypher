// Stage 1 exercise: solutions. Run against the seeded starter graph:
//   cypher-shell -u neo4j -p <password> --file exercises/stage1.cypher

// Step 2: relationships per type, then the number of distinct labels.
MATCH ()-[r]->()
RETURN type(r) AS type, count(*) AS relationships
ORDER BY type;

MATCH (n)
UNWIND labels(n) AS label
RETURN count(DISTINCT label) AS labels;

// Step 3: one row per London resident with their skills and projects.
// COLLECT subqueries avoid the row multiplication that two OPTIONAL MATCHes
// in a row would cause (skills x projects).
MATCH (p:Person {city: 'London'})
RETURN p.handle,
       COLLECT { MATCH (p)-[:KNOWS]->(s:Skill) RETURN s.name ORDER BY s.name } AS skills,
       COLLECT { MATCH (p)-[:WORKS_ON]->(pr:Project) RETURN pr.slug ORDER BY pr.slug } AS projects
ORDER BY p.handle;

// Step 4 is deliberately not in this file: run it by hand and read the error.
//   MATCH (p:Person {handle: 'ada'}) DELETE p;
//   G1001: dependent object error - edges still exist
