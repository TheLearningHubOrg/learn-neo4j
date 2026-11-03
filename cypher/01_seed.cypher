// 01_seed.cypher
// A small developer community: people follow each other, know skills at a
// level from 1 to 5, and work on projects that depend on other projects.
// Every write is a MERGE on a constrained key, so running the file twice
// changes nothing.

// ---- nodes -------------------------------------------------------------------
UNWIND [
  {handle: 'ada', name: 'Ada Okafor',    city: 'London',    joined: date('2021-03-14')},
  {handle: 'bo',  name: 'Bo Lindqvist',  city: 'Stockholm', joined: date('2020-11-02')},
  {handle: 'cy',  name: 'Cy Moreau',     city: 'Lyon',      joined: date('2022-06-30')},
  {handle: 'dee', name: 'Dee Patel',     city: 'Pune',      joined: date('2023-01-17')},
  {handle: 'eli', name: 'Eli Nakamura',  city: 'Osaka',     joined: date('2021-09-05')},
  {handle: 'fay', name: 'Fay Duarte',    city: 'Lisbon',    joined: date('2024-02-29')},
  {handle: 'gus', name: 'Gus Novak',     city: 'Prague',    joined: date('2022-10-11')},
  {handle: 'hal', name: 'Hal Brennan',   city: 'London',    joined: date('2023-08-21')}
] AS row
MERGE (p:Person {handle: row.handle})
SET p.name = row.name, p.city = row.city, p.joined = row.joined;

UNWIND [
  {name: 'Cypher', kind: 'query'},
  {name: 'Java', kind: 'language'},
  {name: 'Go', kind: 'language'},
  {name: 'Python', kind: 'language'},
  {name: 'Rust', kind: 'language'},
  {name: 'Kubernetes', kind: 'platform'}
] AS row
MERGE (s:Skill {name: row.name})
SET s.kind = row.kind;

UNWIND [
  {slug: 'core-lib', name: 'Core Lib', stars: 120,
   description: 'Shared Java utilities for configuration, logging and retries'},
  {slug: 'auth-service', name: 'Auth Service', stars: 340,
   description: 'Token issuing service written in Go'},
  {slug: 'ui-kit', name: 'UI Kit', stars: 95,
   description: 'Design system components and icons'},
  {slug: 'graph-gateway', name: 'Graph Gateway', stars: 510,
   description: 'GraphQL gateway that federates the auth and catalog services'},
  {slug: 'ingest-pipeline', name: 'Ingest Pipeline', stars: 210,
   description: 'Streams events into the graph with Python workers'},
  {slug: 'metrics-agent', name: 'Metrics Agent', stars: 180,
   description: 'Rust agent that ships host metrics'}
] AS row
MERGE (p:Project {slug: row.slug})
SET p.name = row.name, p.description = row.description, p.stars = row.stars;

// ---- relationships -----------------------------------------------------------
// MATCH both ends first, then MERGE only the relationship. MERGE on a whole
// pattern would create missing nodes as well, which hides typos in the data.
UNWIND [
  ['ada', 'bo'], ['ada', 'cy'], ['bo', 'dee'], ['bo', 'eli'], ['cy', 'eli'],
  ['cy', 'gus'], ['dee', 'ada'], ['eli', 'fay'], ['fay', 'hal'], ['gus', 'hal'],
  ['hal', 'ada']
] AS pair
MATCH (a:Person {handle: pair[0]}), (b:Person {handle: pair[1]})
MERGE (a)-[:FOLLOWS]->(b);

UNWIND [
  {who: 'ada', skill: 'Cypher', level: 5}, {who: 'ada', skill: 'Java', level: 3},
  {who: 'bo', skill: 'Go', level: 5},      {who: 'bo', skill: 'Kubernetes', level: 4},
  {who: 'cy', skill: 'Python', level: 4},  {who: 'cy', skill: 'Cypher', level: 3},
  {who: 'dee', skill: 'Java', level: 4},   {who: 'dee', skill: 'Rust', level: 2},
  {who: 'eli', skill: 'Rust', level: 5},   {who: 'eli', skill: 'Go', level: 3},
  {who: 'fay', skill: 'Python', level: 3},
  {who: 'gus', skill: 'Kubernetes', level: 5}, {who: 'gus', skill: 'Go', level: 4},
  {who: 'hal', skill: 'Cypher', level: 4}, {who: 'hal', skill: 'Python', level: 2}
] AS row
MATCH (p:Person {handle: row.who}), (s:Skill {name: row.skill})
MERGE (p)-[k:KNOWS]->(s)
SET k.level = row.level;

UNWIND [
  {who: 'ada', project: 'graph-gateway', role: 'lead', since: 2022},
  {who: 'ada', project: 'core-lib', role: 'contributor', since: 2021},
  {who: 'bo', project: 'auth-service', role: 'lead', since: 2021},
  {who: 'bo', project: 'graph-gateway', role: 'contributor', since: 2023},
  {who: 'cy', project: 'ingest-pipeline', role: 'lead', since: 2022},
  {who: 'dee', project: 'core-lib', role: 'lead', since: 2023},
  {who: 'eli', project: 'metrics-agent', role: 'lead', since: 2021},
  {who: 'fay', project: 'ingest-pipeline', role: 'contributor', since: 2024},
  {who: 'gus', project: 'auth-service', role: 'contributor', since: 2022},
  {who: 'hal', project: 'graph-gateway', role: 'contributor', since: 2024},
  {who: 'hal', project: 'ui-kit', role: 'lead', since: 2023}
] AS row
MATCH (p:Person {handle: row.who}), (pr:Project {slug: row.project})
MERGE (p)-[w:WORKS_ON]->(pr)
SET w.role = row.role, w.since = row.since;

UNWIND [
  ['graph-gateway', 'auth-service'], ['graph-gateway', 'ui-kit'],
  ['auth-service', 'core-lib'], ['ui-kit', 'core-lib'],
  ['ingest-pipeline', 'metrics-agent'], ['ingest-pipeline', 'core-lib'],
  ['metrics-agent', 'core-lib']
] AS pair
MATCH (a:Project {slug: pair[0]}), (b:Project {slug: pair[1]})
MERGE (a)-[:DEPENDS_ON]->(b);

UNWIND [
  ['core-lib', 'Java'], ['auth-service', 'Go'], ['auth-service', 'Kubernetes'],
  ['graph-gateway', 'Cypher'], ['graph-gateway', 'Go'],
  ['ingest-pipeline', 'Python'], ['ingest-pipeline', 'Cypher'],
  ['metrics-agent', 'Rust']
] AS pair
MATCH (p:Project {slug: pair[0]}), (s:Skill {name: pair[1]})
MERGE (p)-[:USES]->(s);
