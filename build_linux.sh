#!/bin/bash
set -e # stop on error

cd CasparCG-Server

BUCKET_ID=$(echo $ORIG_COMMIT_REF | sed -r 's/[^a-z0-9]+/-/gi')
COUNT=$(git rev-list --count HEAD)
RESULT_NAME="CasparCG_Server_${ORIG_COMMIT_ID}_${COUNT}_${PLATFORM}.tar.gz"

if [ -d "build-scripts/${PLATFORM}" ]; then # 2.2.0 build script
  # TODO - remove/change the url if it isnt going to be deployed
  curl -XPOST -H 'Accept: application/vnd.github.v3+json' -H 'Authorization: token ${GITHUB_OAUTH}' -d '{
    "state": "pending",
    "target_url": "https://caspar.julusian.co.uk/'$BUCKET_ID'",
    "description": "Pending: The '$PLATFORM' build is in progress",
    "context": "travis-custom/'$PLATFORM'"
  }' "https://api.github.com/repos/${ORIG_REPO_NAME}/statuses/${ORIG_COMMIT_ID}" || true

# write the build script for docker, because its easier to make it run multiple commands this way
cat >build-scripts/$PLATFORM/inner <<EOL
cmake /source
make -j2
/source/build-scripts/$PLATFORM/package
EOL

  chmod +x build-scripts/$PLATFORM/inner

  "./build-scripts/$PLATFORM/build-docker-image"
  # exec the build in docker, cant use the wrapper as it doesnt pass any script args in
  docker run --rm -it \
      -v $PWD:/source \
      -v $PWD/products:/build/products \
      "casparcg/server-build:$PLATFORM" /bin/bash "/source/build-scripts/$PLATFORM/inner"


  cd products

  sudo chmod 777 . -R
  mv "CasparCG_Server_${PLATFORM}.tar.gz" "$RESULT_NAME"

elif [ "$PLATFORM" == "linux" ] && [ ! -d "build-scripts/ubuntu-17.10" ]; then # 2.1.0 build script
  # TODO - remove/change the url if it isnt going to be deployed
  curl -XPOST -H 'Accept: application/vnd.github.v3+json' -H 'Authorization: token ${GITHUB_OAUTH}' -d '{
    "state": "pending",
    "target_url": "https://caspar.julusian.co.uk/'$BUCKET_ID'",
    "description": "Pending: The '$PLATFORM' build is in progress",
    "context": "travis-custom/'$PLATFORM'"
  }' "https://api.github.com/repos/${ORIG_REPO_NAME}/statuses/${ORIG_COMMIT_ID}" || true

  sudo apt-get update
  sudo apt-get install libxrandr-dev libjpeg-dev libsndfile1-dev libudev-dev libglu1-mesa-dev
  sudo apt-get install libv4l-0 libraw1394-11 libavc1394-0 libiec61883-0 libgdk-pixbuf2.0-0 \
      libxi6 libasound2 libcups2 libatk1.0-0 libpangocairo-1.0-0 libxtst6 libxcomposite1 \
      libnss3 libgtk2.0-0 libgconf2-4

  cd build-scripts
  export BUILD_ARCHIVE_NAME="CasparCG Server"
  export BUILD_PARALLEL_THREADS=4

  ./build-linux.sh

  cd ../build
  mv "CasparCG Server.tar.gz" "$RESULT_NAME"

else
  echo "Build type not supported on this commit"
  exit 0
fi

# secrets are only defined on non-pr builds, so dont try to upload if it is a pr
# not relevent via the api hook method though
# if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
  sudo wget https://dl.minio.io/client/mc/release/linux-amd64/mc
  sudo chmod +x mc
  ./mc -C ./ config host add minio $S3_URL $S3_ACCESS_KEY $S3_SECRET_KEY S3v4
  ./mc -C ./ mb minio/$BUCKET_ID
  ./mc -C ./ cp "$RESULT_NAME" minio/$BUCKET_ID
# fi

# TODO - remove/change the url if it isnt going to be deployed
curl -XPOST -H 'Accept: application/vnd.github.v3+json' -H 'Authorization: token ${GITHUB_OAUTH}' -d '{
  "state": "success",
  "target_url": "https://caspar.julusian.co.uk/'$BUCKET_ID'",
  "description": "Success: The '$PLATFORM' build is complete",
  "context": "travis-custom/'$PLATFORM'"
}' "https://api.github.com/repos/${ORIG_REPO_NAME}/statuses/${ORIG_COMMIT_ID}" || true
