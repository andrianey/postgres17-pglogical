FROM postgres:17

# Install curl and ca-certificates to download the repository key
RUN apt-get update && apt-get install -y curl ca-certificates gnupg lsb-release

# Add the 2ndQuadrant (now EDB) repository or PostgreSQL Global Development Group (PGDG) repo
# The standard postgres image relies on PGDG repo usually.
# pglogical is available in PGDG repo.

RUN apt-get update \
    && apt-get install -y postgresql-17-pglogical \
    && rm -rf /var/lib/apt/lists/*

