#!/bin/bash
set -e # stop on error

cd CasparCG-Server

if [ "$PLATFORM" == "legacy" ]; then
  # TODO - combine it so that the upload steps below are shared
  exit 0
fi

# check if build is supported
if [ ! -d "build-scripts/${PLATFORM}" ]; then
  echo "Build type not supported"
  exit 0
fi

BUCKET_ID=$(echo $ORIG_COMMIT_REF | sed -r 's/[^a-z0-9]+/-/gi')

# TODO - remove/change the url if it isnt going to be deployed
curl -XPOST -H 'Accept: application/vnd.github.v3+json' -H 'Authorization: token ${GITHUB_OAUTH}' -d '{
  "state": "pending",
  "target_url": "https://caspar.julusian.co.uk/'$BUCKET_ID'",
  "description": "Pending: The '$PLATFORM' build is in progress",
  "context": "travis-custom/'$PLATFORM'"
}' "https://api.github.com/repos/${ORIG_REPO_NAME}/statuses/${ORIG_COMMIT_ID}" || true


"./build-scripts/$PLATFORM/build-docker-image"
"./build-scripts/$PLATFORM/launch-interactive" cmake /source && make -j2 && "/source/build-scripts/$PLATFORM/package"

# secrets are only defined on non-pr builds, so dont try to upload if it is a pr
# not relevent via the api hook method though
# if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
  COUNT=$(git rev-list --count HEAD)
  NEW_NAME="CasparCG_Server_${ORIG_COMMIT_ID}_${COUNT}_${PLATFORM}.tar.gz"

  cd build/products
  mv "CasparCG_Server_${PLATFORM}.tar.gz" "$NEW_NAME"
  mc -C ./ config host add minio $S3_URL $S3_ACCESS_KEY $S3_SECRET_KEY S3v4
  mc -C ./ mb minio/$BUCKET_ID
  mc -C ./ cp "$NEW_NAME" minio/$BUCKET_ID
# fi

# TODO - remove/change the url if it isnt going to be deployed
curl -XPOST -H 'Accept: application/vnd.github.v3+json' -H 'Authorization: token ${GITHUB_OAUTH}' -d '{
  "state": "success",
  "target_url": "https://caspar.julusian.co.uk/'$BUCKET_ID'",
  "description": "Success: The '$PLATFORM' build is complete",
  "context": "travis-custom/'$PLATFORM'"
}' "https://api.github.com/repos/${ORIG_REPO_NAME}/statuses/${ORIG_COMMIT_ID}" || true
