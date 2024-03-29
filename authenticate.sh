#! /bin/bash

set -e

echo "Activating gcloud service account"

echo $GCLOUD_KEY | base64 --decode > gcloud.p12

gcloud auth activate-service-account $GCLOUD_EMAIL --key-file gcloud.p12

if [ ! -e ~/.ssh/google_compute_engine ]; then
  ssh-keygen -f ~/.ssh/google_compute_engine -N ""
fi

gcloud docker -a
