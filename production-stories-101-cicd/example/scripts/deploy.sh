#!/usr/bin/env bash
# Placeholder deploy. Replace the body with your platform's CLI
# (container push, serverless deploy, rsync, etc.).
# Contract: deploy the artifact for $GIT_SHA and exit non-zero on failure.
set -euo pipefail
: "${GIT_SHA:?GIT_SHA is required}"
echo "Deploying ${GIT_SHA} (placeholder, nothing is actually deployed)"
