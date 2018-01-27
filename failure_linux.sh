#!/bin/bash
set -e # stop on error

BUCKET_ID=$(echo $ORIG_COMMIT_REF | sed -r 's/[^a-z0-9]+/-/gi')

curl -XPOST -H 'Accept: application/vnd.github.v3+json' -H 'Authorization: token ${GITHUB_OAUTH}' -d '{
  "state": "failure",
  "description": "Failed: The '$PLATFORM' build has failed",
  "context": "travis-custom/'$PLATFORM'"
}' "https://api.github.com/repos/${ORIG_REPO_NAME}/statuses/${ORIG_COMMIT_ID}" || true
