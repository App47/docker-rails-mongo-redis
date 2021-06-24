#!/bin/bash
set -Eeuo pipefail

ruby --version
exec -l "$@"
