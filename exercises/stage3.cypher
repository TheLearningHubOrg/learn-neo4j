// Stage 3 exercise: solutions. Run against the seeded starter graph:
//   cypher-shell -u neo4j -p <password> --file exercises/stage3.cypher

// Step 1: direct dependencies and the transitive closure per project.
MATCH (pr:Project)
RETURN pr.slug AS project,
       coll.sort(COLLECT { MATCH (pr)-[:DEPENDS_ON]->(d) RETURN d.slug }) AS direct,
       coll.sort(COLLECT { MATCH (pr)-[:DEPENDS_ON]->+(d) RETURN DISTINCT d.slug }) AS closure
ORDER BY project;

// Step 2: two hops from bo, excluding bo and the people bo already follows.
MATCH (me:Person {handle: 'bo'})-[:FOLLOWS]->(friend:Person)-[:FOLLOWS]->(fof:Person)
WHERE fof <> me AND NOT (me)-[:FOLLOWS]->(fof)
RETURN fof.handle AS suggestion, count(DISTINCT friend) AS mutual,
       collect(DISTINCT friend.handle) AS via
ORDER BY mutual DESC, suggestion;

// Step 3: the project with the most transitive dependents.
MATCH (d:Project)-[:DEPENDS_ON]->+(target:Project)
WITH target, count(DISTINCT d) AS dependents
ORDER BY dependents DESC, target.slug
LIMIT 1
RETURN target.slug AS project, dependents;

// Step 4: run the step 2 query with PROFILE in front (in cypher-shell use
// --format verbose). The leaf operator is NodeUniqueIndexSeek on person_handle.

// Step 5: shortest follow chain from dee to gus.
MATCH p = SHORTEST 1 (:Person {handle: 'dee'})-[:FOLLOWS]->+(:Person {handle: 'gus'})
RETURN [n IN nodes(p) | n.handle] AS route;
