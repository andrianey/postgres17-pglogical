@echo off
echo Cleaning up environment...
docker compose down -v
echo Starting services...
docker compose up -d
echo Waiting for services to be ready...
timeout /t 10 /nobreak > nul

echo.
echo *** Setting up Node A (Publisher/Subscriber) ***
docker exec -i pg_publisher psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pglogical;"
docker exec -i pg_publisher psql -U postgres -c "SELECT pglogical.create_node(node_name := 'node_a', dsn := 'host=pg_publisher port=5432 dbname=postgres user=postgres password=password');"
docker exec -i pg_publisher psql -U postgres -c "CREATE TABLE IF NOT EXISTS bi_table (id serial PRIMARY KEY, data text, updated_at timestamptz DEFAULT now());"
docker exec -i pg_publisher psql -U postgres -c "SELECT pglogical.replication_set_add_all_tables('default', '{public}');"

echo.
echo *** Setting up Node B (Publisher/Subscriber) ***
docker exec -i pg_subscriber psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pglogical;"
docker exec -i pg_subscriber psql -U postgres -c "SELECT pglogical.create_node(node_name := 'node_b', dsn := 'host=pg_subscriber port=5432 dbname=postgres user=postgres password=password');"
docker exec -i pg_subscriber psql -U postgres -c "CREATE TABLE IF NOT EXISTS bi_table (id serial PRIMARY KEY, data text, updated_at timestamptz DEFAULT now());"
docker exec -i pg_subscriber psql -U postgres -c "SELECT pglogical.replication_set_add_all_tables('default', '{public}');"

echo.
echo *** Creating Subscriptions (Bidirectional) ***
echo Node A subscribes to Node B...
docker exec -i pg_publisher psql -U postgres -c "SELECT pglogical.create_subscription(subscription_name := 'sub_a_to_b', provider_dsn := 'host=pg_subscriber port=5432 dbname=postgres user=postgres password=password');"

echo Node B subscribes to Node A...
docker exec -i pg_subscriber psql -U postgres -c "SELECT pglogical.create_subscription(subscription_name := 'sub_b_to_a', provider_dsn := 'host=pg_publisher port=5432 dbname=postgres user=postgres password=password');"

echo.
echo *** Verifying Sync (A to B) ***
docker exec -i pg_publisher psql -U postgres -c "INSERT INTO bi_table (id, data) VALUES (1, 'initial_a');"
timeout /t 5 /nobreak > nul
echo Checking Node B:
docker exec -i pg_subscriber psql -U postgres -c "SELECT * FROM bi_table WHERE id=1;"

echo.
echo *** Verifying Sync (B to A) ***
docker exec -i pg_subscriber psql -U postgres -c "INSERT INTO bi_table (id, data) VALUES (2, 'initial_b');"
timeout /t 5 /nobreak > nul
echo Checking Node A:
docker exec -i pg_publisher psql -U postgres -c "SELECT * FROM bi_table WHERE id=2;"

echo.
echo *** Testing Conflict Resolution (Last Update Wins) ***
echo updating id=1 on Node A...
docker exec -i pg_publisher psql -U postgres -c "UPDATE bi_table SET data='update_from_A', updated_at=now() WHERE id=1;"
echo updating id=1 on Node B (delayed to ensure it is newer)...
timeout /t 2 /nobreak > nul
docker exec -i pg_subscriber psql -U postgres -c "UPDATE bi_table SET data='update_from_B', updated_at=now() WHERE id=1;"

echo Waiting for sync...
timeout /t 5 /nobreak > nul

echo Result on Node A (Should be 'update_from_B'):
docker exec -i pg_publisher psql -U postgres -c "SELECT * FROM bi_table WHERE id=1;"
echo Result on Node B (Should be 'update_from_B'):
docker exec -i pg_subscriber psql -U postgres -c "SELECT * FROM bi_table WHERE id=1;"
