#! /bin/bash

set -e

usage="Usage: './rolling_deploy.sh image-name selector namespace context rc' e.g. './rolling_deploy.sh myImageName app=myApp myNamespace . ./kubernetes/rc.yaml'"

if [[ $# -ne 5 ]]; then
    echo "Incorrect number of arguments, 5 required";
    echo $usage;
    exit 1;
fi

IMAGE=$1;
SELECTOR=$2;
NAMESPACE=$3
CONTEXT=$4
RC_FILE=$5

TAG=${CIRCLE_SHA1:0:7}
REMOTE_REPOSITORY=${GCLOUD_REGISTRY_PREFIX}gcr.io/${CLOUDSDK_CORE_PROJECT}
QUALIFIED_IMAGE_NAME=${REMOTE_REPOSITORY}/${IMAGE}:${TAG}

export CLOUDSDK_CORE_DISABLE_PROMPTS=1
export CLOUDSDK_PYTHON_SITEPACKAGES=1

# Build image
docker build -t ${QUALIFIED_IMAGE_NAME} ${CONTEXT}

# Authenticate gcloud SDK
echo $GCLOUD_KEY | base64 --decode > gcloud.p12
~/google-cloud-sdk/bin/gcloud auth activate-service-account $GCLOUD_EMAIL --key-file gcloud.p12
ssh-keygen -f ~/.ssh/google_compute_engine -N ""

# Set cluster
~/google-cloud-sdk/bin/gcloud container clusters get-credentials $GCLOUD_CLUSTER

# Push image to gcloud
~/google-cloud-sdk/bin/gcloud docker push ${QUALIFIED_IMAGE_NAME} > /dev/null

# Rolling update
OLD_RC=$(~/google-cloud-sdk/bin/kubectl get rc -l ${SELECTOR} --namespace=${NAMESPACE} -o template --template="{{(index .items 0).metadata.name}}")
REPLICAS=$(~/google-cloud-sdk/bin/kubectl get rc ${OLD_RC} --namespace=${NAMESPACE} -o template --template="{{.spec.replicas}}")

# Expand env variables and perform rolling update
cat ${RC_FILE} | perl -pe 's/\{\{(\w+)\}\}/$ENV{$1}/eg' | \
  ~/google-cloud-sdk/bin/kubectl rolling-update ${OLD_RC} --namespace=${NAMESPACE} -f -

