#! /bin/bash

set -e

usage="Usage: './rolling_deploy.sh image-name selector namespace context rc' e.g. './rolling_deploy.sh myImageName app=myApp myNamespace . ./kubernetes/rc.json'"

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

export NAMESPACE=$NAMESPACE
export TAG=${CIRCLE_SHA1:0:7}-ci${CIRCLE_BUILD_NUM}
export QUALIFIED_IMAGE_NAME=${GCLOUD_REGISTRY_PREFIX}gcr.io/${CLOUDSDK_CORE_PROJECT}/${IMAGE}:${TAG}
export CLOUDSDK_CORE_DISABLE_PROMPTS=1
export CLOUDSDK_PYTHON_SITEPACKAGES=1
export DEPLOYMENT_ID=$CIRCLE_BUILD_NUM

echo "Building image ${QUALIFIED_IMAGE_NAME} with context ${CONTEXT}"
docker build -t ${QUALIFIED_IMAGE_NAME} ${CONTEXT}

echo "Activating service account"
echo $GCLOUD_KEY | base64 --decode > gcloud.p12
~/google-cloud-sdk/bin/gcloud auth activate-service-account $GCLOUD_EMAIL --key-file gcloud.p12
ssh-keygen -f ~/.ssh/google_compute_engine -N ""

echo "Authenticating gcloud SDK"
~/google-cloud-sdk/bin/gcloud container clusters get-credentials $GCLOUD_CLUSTER

echo "Pusing image to registry"
~/google-cloud-sdk/bin/gcloud docker push ${QUALIFIED_IMAGE_NAME} > /dev/null

OLD_RC=$(~/google-cloud-sdk/bin/kubectl get rc -l ${SELECTOR} --namespace=${NAMESPACE} -o template --template="{{(index .items 0).metadata.name}}")
echo "Old replication controller name: ${OLD_RC}"

export REPLICAS=$(~/google-cloud-sdk/bin/kubectl get rc ${OLD_RC} --namespace=${NAMESPACE} -o template --template="{{.spec.replicas}}")
echo "Current replicas: ${REPLICAS}"

echo "Expanding variables in config file"
cat ${RC_FILE} | perl -pe 's/\{\{(\w+)\}\}/$ENV{$1}/eg' > rc.txt

echo "Updating using config:"
cat rc.txt

cat rc.txt | ~/google-cloud-sdk/bin/kubectl rolling-update ${OLD_RC} --namespace=${NAMESPACE} -f -

