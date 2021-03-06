CREATE TABLE 'accounts' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'firm_id' INTEGER DEFAULT NULL,
  'credit_limit' INTEGER DEFAULT NULL
);

CREATE TABLE 'companies' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'type' VARCHAR(255) DEFAULT NULL,
  'firm_id' INTEGER DEFAULT NULL,
  'name' TEXT DEFAULT NULL,
  'client_of' INTEGER DEFAULT NULL,
  'companies_count' INTEGER DEFAULT 0,
  'rating' INTEGER DEFAULT 1
);


CREATE TABLE 'topics' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'title' VARCHAR(255) DEFAULT NULL,
  'author_name' VARCHAR(255) DEFAULT NULL,
  'author_email_address' VARCHAR(255) DEFAULT NULL,
  'written_on' DATETIME DEFAULT NULL,
  'last_read' DATE DEFAULT NULL,
  'content' TEXT,
  'approved' INTEGER DEFAULT 1,
  'reply_count' INTEGER DEFAULT NULL,
  'parent_id' INTEGER DEFAULT NULL,
  'type' VARCHAR(255) DEFAULT NULL
);

CREATE TABLE 'developers' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'name' TEXT DEFAULT NULL
);

CREATE TABLE 'projects' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'name' TEXT DEFAULT NULL
);

CREATE TABLE 'developers_projects' (
  'developer_id' INTEGER NOT NULL,
  'project_id' INTEGER NOT NULL
);

CREATE TABLE 'customers' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'name' VARCHAR(255) DEFAULT NULL,
  'balance' INTEGER DEFAULT 0,
  'address_street' TEXT DEFAULT NULL,
  'address_city' TEXT DEFAULT NULL,
  'address_country' TEXT DEFAULT NULL
);

CREATE TABLE 'movies' (
  'movieid' INTEGER PRIMARY KEY NOT NULL,
  'name' VARCHAR(255) DEFAULT NULL
);

CREATE TABLE subscribers (
 'nick' VARCHAR(255) PRIMARY KEY NOT NULL,
 'name' VARCHAR(255) DEFAULT NULL
);
