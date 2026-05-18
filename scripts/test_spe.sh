#!/usr/bin/env bash
set -euo pipefail

cd spe_project
mix deps.get
mix test
