#!/bin/bash
set -e # stop on error

rmdir CasparCG-Server || true

# clone the repo
mkdir CasparCG-Server
cd CasparCG-Server

git init
git remote add origin $ORIG_REPO_URL # https://github.com/CasparCG/Server.git
git fetch origin $ORIG_COMMIT_REF # refs/heads/2.2.0
git checkout $ORIG_COMMIT_ID # f613d9a79031136dc7f58ff7a946344c05ea1c53
