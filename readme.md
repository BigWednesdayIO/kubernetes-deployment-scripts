# Google Cloud Platform Integration

Scripts for integrating with google cloud platform

## kubernetes_deploy.sh
Deploy or re-deploy a kubernetes replica controller and service

```
./kubernetes_deploy.sh myImageName app=myApp myNamespace . ./kubernetes/rc.json ./kubernetes/service.json
```

### Required variables
- CLOUDSDK_CORE_PROJECT - project name
- CLOUDSDK_COMPUTE_ZONE - gcloud compute zone
- GCLOUD_CLUSTER - cluster to deploy to
- GCLOUD_EMAIL - email of the GCloud service account
- GCLOUD_KEY - base 64 encoded single JSON cert of the GCloud service account
- GCLOUD_REGISTRY_PREFIX - where the image registry should be located. Blank for US, "eu." for Europe

### Optional variables
- OVERRIDE_IMAGE_TAG - tag for the container image e.g. dev (falls back to [commit-hash]-ci[build_number] from circle ci)

## install_sdk.sh
Install gcloud sdk to ~/google-cloud-sdk

## authenticate.sh
Authenticate gcloud sdk

