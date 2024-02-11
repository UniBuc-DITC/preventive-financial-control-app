#!/usr/bin/env bash

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE "development";
    GRANT ALL PRIVILEGES ON DATABASE "development" TO ${POSTGRES_USER};

    CREATE DATABASE "test";
    GRANT ALL PRIVILEGES ON DATABASE "test" TO ${POSTGRES_USER};
EOSQL
