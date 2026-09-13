CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE documents (
    id bigserial PRIMARY KEY,
    source text NOT NULL,
    department text NOT NULL,
    country text NOT NULL,
    content text NOT NULL,
    embedding vector(1536) NOT NULL
);

CREATE INDEX documents_country_department_idx
    ON documents (country, department);
