// 00_schema.cypher
// Constraints first, then indexes. Every statement uses IF NOT EXISTS, so the
// file is safe to run again. Community Edition supports property uniqueness
// constraints only; existence, type and key constraints need Enterprise.

// A uniqueness constraint is backed by a RANGE index, so MATCH and MERGE on
// these properties are index seeks, not label scans.
CREATE CONSTRAINT person_handle IF NOT EXISTS
FOR (p:Person) REQUIRE p.handle IS UNIQUE;

CREATE CONSTRAINT skill_name IF NOT EXISTS
FOR (s:Skill) REQUIRE s.name IS UNIQUE;

CREATE CONSTRAINT project_slug IF NOT EXISTS
FOR (p:Project) REQUIRE p.slug IS UNIQUE;

// Range index for equality and range filters on a non-unique property.
CREATE INDEX person_city IF NOT EXISTS
FOR (p:Person) ON (p.city);

// Relationship property index: "who joined a project since 2023" starts here.
CREATE INDEX works_on_since IF NOT EXISTS
FOR ()-[w:WORKS_ON]-() ON (w.since);

// Text index: speeds up CONTAINS and ENDS WITH on string properties.
CREATE TEXT INDEX project_name_text IF NOT EXISTS
FOR (p:Project) ON (p.name);

// Full-text (Lucene) index: tokenised, scored search across several properties.
CREATE FULLTEXT INDEX project_search IF NOT EXISTS
FOR (p:Project) ON EACH [p.name, p.description];

// Indexes populate in the background; wait so the seed and tests use them.
CALL db.awaitIndexes(120);
