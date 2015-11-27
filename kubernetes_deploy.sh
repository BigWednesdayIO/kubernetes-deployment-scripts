#! /bin/bash

set -e

usage="Usage: './kubernetes_deploy.sh image-name selector namespace context rc' e.g. './kubernetes_deploy.sh myImageName app=myApp myNamespace . ./kubernetes/rc.json ./kubernetes/service.json'"

if [[ $# -ne 6 ]]; then
    echo "Incorrect number of arguments, 6 required";
    echo $usage;
    exit 1;
fi

IMAGE=$1;
SELECTOR=$2;
NAMESPACE=$3
CONTEXT=$4
RC_FILE=$5
SVC_FILE=$6

export NAMESPACE=$NAMESPACE
export VERSION=${CIRCLE_SHA1:0:7}-ci${CIRCLE_BUILD_NUM}
IMAGE_TAG=${OVERRIDE_IMAGE_TAG:-${VERSION}}
export QUALIFIED_IMAGE_NAME=${GCLOUD_REGISTRY_PREFIX}gcr.io/${CLOUDSDK_CORE_PROJECT}/${IMAGE}:${IMAGE_TAG}
export CLOUDSDK_CORE_DISABLE_PROMPTS=1
export CLOUDSDK_PYTHON_SITEPACKAGES=1
export DEPLOYMENT_ID=$CIRCLE_BUILD_NUM

echo "Installing json command line tool"
npm install -g json

echo "Building image ${QUALIFIED_IMAGE_NAME} with context ${CONTEXT}"
docker build -t ${QUALIFIED_IMAGE_NAME} ${CONTEXT}

source ./authenticate.sh

echo "Authenticating against cluster"
~/google-cloud-sdk/bin/gcloud container clusters get-credentials $GCLOUD_CLUSTER

echo "Pushing image to registry"
~/google-cloud-sdk/bin/gcloud docker push ${QUALIFIED_IMAGE_NAME} > /dev/null

echo "Expanding variables in service config file"
cat ${SVC_FILE} | perl -pe 's/\{\{(\w+)\}\}/$ENV{$1}/eg' > svc.txt
echo "Checking for existing svc"
SVC_NAME=$(cat svc.txt | json metadata.name)
SVC_EXISTS=$(~/google-cloud-sdk/bin/kubectl get svc $SVC_NAME --namespace=${NAMESPACE} || true)
if [[ -z $SVC_EXISTS ]]; then
  echo "Creating svc $SVC_NAME"
  cat svc.txt | ~/google-cloud-sdk/bin/kubectl create --namespace=${NAMESPACE} -f -
fi
if [[ -n $SVC_EXISTS ]]; then
  echo "svc $SVC_NAME is already deployed"
fi

echo "Checking for existing rc"
RC_QUERY_RESULT=$(~/google-cloud-sdk/bin/kubectl get rc -l ${SELECTOR} --namespace=${NAMESPACE} -o template --template="{{.items}}")
if [[ $RC_QUERY_RESULT == "[]" ]]; then
  echo "Deploying new rc"

  export REPLICAS=1
  cat ${RC_FILE} | perl -pe 's/\{\{(\w+)\}\}/$ENV{$1}/eg' > rc.txt

  echo Checking all required secrets exist
  SECRETS=$(cat rc.txt | json spec.template.spec.volumes | json -a secret.secretName)
  for s in $(echo $SECRETS | tr " " "\n")
  do
     SECRET_EXISTS=$(~/google-cloud-sdk/bin/kubectl get secret $s --namespace=${NAMESPACE} || true)
     if [[ -z $SECRET_EXISTS ]]; then
      echo "Secret $s does not exist in namespace $NAMESPACE"
      exit 1
     fi
     unset SECRET_EXISTS
  done

  echo "Creating rc"
  cat rc.txt | ~/google-cloud-sdk/bin/kubectl create --namespace=${NAMESPACE} -f -
fi

if [[ $RC_QUERY_RESULT != "[]" ]]; then
  echo "Performing rc rolling update"

  OLD_RC_NAME=$(~/google-cloud-sdk/bin/kubectl get rc -l ${SELECTOR} --namespace=${NAMESPACE} -o template --template="{{(index .items 0).metadata.name}}")
  echo "Old replication controller name: ${OLD_RC_NAME}"

  export REPLICAS=$(~/google-cloud-sdk/bin/kubectl get rc ${OLD_RC_NAME} --namespace=${NAMESPACE} -o template --template="{{.spec.replicas}}")
  echo "Current replicas: ${REPLICAS}"

  echo "Expanding variables in rc config file"
  cat ${RC_FILE} | perl -pe 's/\{\{(\w+)\}\}/$ENV{$1}/eg' > rc.txt

  echo "Updating rc"
  cat rc.txt | ~/google-cloud-sdk/bin/kubectl rolling-update ${OLD_RC_NAME} --namespace=${NAMESPACE} -f -
fi




