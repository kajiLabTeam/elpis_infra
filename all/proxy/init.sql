CREATE TABLE organizations (
    api_endpoint VARCHAR PRIMARY KEY,
    scheme VARCHAR,
    port_number INTEGER,
    last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
