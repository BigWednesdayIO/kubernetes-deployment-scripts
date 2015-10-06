#! /bin/bash

set -e

pip install pyopenssl
if [ ! -d ~/google-cloud-sdk ]; then
    echo "Installing gcloud sdk"
    curl https://sdk.cloud.google.com | bash;
    ~/google-cloud-sdk/bin/gcloud components update kubectl
fi
