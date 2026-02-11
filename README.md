# Postgres 17 with pglogical

This project provides a Docker setup for PostgreSQL 17 with the `pglogical` extension installed, suitable for logical replication.

## Prerequisites

- Docker
- Docker Compose

## Quick Start

1.  **Build and Start Services**:

    ```bash
    docker compose up -d --build
    ```

    This will start two containers:
    - `pg_publisher` (Port 5432)
    - `pg_subscriber` (Port 5433)

2.  **Verify Installation**:

    Access the publisher:
    ```bash
    docker exec -it pg_publisher psql -U postgres
    ```
    Inside psql run:
    ```sql
    CREATE EXTENSION pglogical;
    \dx pglogical
    ```

## Replication Setup Example

### 1. Configure Publisher

Connect to the publisher (`localhost:5432`):

```sql
-- Create extension
CREATE EXTENSION pglogical;

-- Create subscriber provider node
SELECT pglogical.create_node(
    node_name := 'provider',
    dsn := 'host=pg_publisher port=5432 dbname=postgres user=postgres password=password'
);

-- Create a table and add data
CREATE TABLE test_table (id serial PRIMARY KEY, data text);
INSERT INTO test_table (data) VALUES ('row1'), ('row2');

-- Send table to replication set
SELECT pglogical.replication_set_add_all_tables('default', '{public}');
```

### 2. Configure Subscriber

Connect to the subscriber (`localhost:5433`):

```sql
-- Create extension
CREATE EXTENSION pglogical;

-- Create subscriber node
SELECT pglogical.create_node(
    node_name := 'subscriber',
    dsn := 'host=pg_subscriber port=5432 dbname=postgres user=postgres password=password'
);

-- Create the table structure (required)
CREATE TABLE test_table (id serial PRIMARY KEY, data text);

-- Create subscription
SELECT pglogical.create_subscription(
    subscription_name := 'subscription1',
    provider_dsn := 'host=pg_publisher port=5432 dbname=postgres user=postgres password=password'
);
```

### 3. Verify Sync

On the subscriber, check the data:

```sql
SELECT * FROM test_table;
```

You should see the rows from the publisher.
