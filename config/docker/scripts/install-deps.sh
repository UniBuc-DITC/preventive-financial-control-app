#!/usr/bin/env bash

# Script to install binary dependencies in production Docker image
# Must be run as root

set -ex

# Install libpq, required by PostgreSQL gem
apt-get update
apt-get install libpq-dev

# Install Node.js (required for preprocessing assets)
apt-get update
apt-get install -y ca-certificates curl gnupg

mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

NODE_MAJOR=20
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

apt-get update
apt-get install -y nodejs
