#!/bin/bash
set -Eeuo pipefail

ruby --version
#mongod -smallfiles -nojournal --fork --logpath /var/log/mongodb.log;
exec -l "$@"
