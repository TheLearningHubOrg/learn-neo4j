// 01_schema_test.cypher
// Every statement returns one row with two columns, test and ok, and ends
// with "AS ok;". scripts/run-tests.sh counts those endings and fails the run
// when a row is missing or ok is not TRUE.

SHOW CONSTRAINTS YIELD name, type
WITH collect(name + ':' + type) AS got
RETURN 'three uniqueness constraints exist' AS test,
       coll.sort(got) = ['person_handle:NODE_PROPERTY_UNIQUENESS', 'project_slug:NODE_PROPERTY_UNIQUENESS',
                         'skill_name:NODE_PROPERTY_UNIQUENESS'] AS ok;

SHOW INDEXES YIELD name, type, owningConstraint
WHERE owningConstraint IS NOT NULL
WITH collect(name) AS backing
RETURN 'each constraint owns a backing index' AS test,
       coll.sort(backing) = ['person_handle', 'project_slug', 'skill_name'] AS ok;

SHOW INDEXES YIELD name, type, entityType
WHERE name IN ['person_city', 'works_on_since', 'project_name_text', 'project_search']
WITH collect(name + ':' + type + ':' + entityType) AS got
RETURN 'range, text and full-text indexes have the expected kinds' AS test,
       coll.sort(got) = ['person_city:RANGE:NODE', 'project_name_text:TEXT:NODE',
                         'project_search:FULLTEXT:NODE', 'works_on_since:RANGE:RELATIONSHIP'] AS ok;

SHOW INDEXES YIELD state
WITH collect(DISTINCT state) AS states
RETURN 'every index is ONLINE' AS test, states = ['ONLINE'] AS ok;

SHOW INDEXES YIELD type
WHERE type = 'LOOKUP'
WITH count(*) AS lookups
RETURN 'token lookup indexes for labels and relationship types exist' AS test, lookups = 2 AS ok;
