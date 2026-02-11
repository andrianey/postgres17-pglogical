@echo off
echo Waiting for services to be ready...
timeout /t 10 /nobreak > nul

echo.
echo *** Setting up Publisher ***
docker exec -i pg_publisher psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pglogical;"
docker exec -i pg_publisher psql -U postgres -c "SELECT pglogical.create_node(node_name := 'provider', dsn := 'host=pg_publisher port=5432 dbname=postgres user=postgres password=password');"
docker exec -i pg_publisher psql -U postgres -c "CREATE TABLE IF NOT EXISTS test_table (id serial PRIMARY KEY, data text);"
docker exec -i pg_publisher psql -U postgres -c "INSERT INTO test_table (data) VALUES ('row1'), ('row2');"
docker exec -i pg_publisher psql -U postgres -c "SELECT pglogical.replication_set_add_all_tables('default', '{public}');"

echo.
echo *** Setting up Subscriber ***
docker exec -i pg_subscriber psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pglogical;"
docker exec -i pg_subscriber psql -U postgres -c "SELECT pglogical.create_node(node_name := 'subscriber', dsn := 'host=pg_subscriber port=5432 dbname=postgres user=postgres password=password');"
docker exec -i pg_subscriber psql -U postgres -c "CREATE TABLE IF NOT EXISTS test_table (id serial PRIMARY KEY, data text);"
docker exec -i pg_subscriber psql -U postgres -c "SELECT pglogical.create_subscription(subscription_name := 'subscription1', provider_dsn := 'host=pg_publisher port=5432 dbname=postgres user=postgres password=password');"

echo.
echo *** Verifying Replication ***
echo Waiting for data to sync...
timeout /t 5 /nobreak > nul
docker exec -i pg_subscriber psql -U postgres -c "SELECT * FROM test_table;"
