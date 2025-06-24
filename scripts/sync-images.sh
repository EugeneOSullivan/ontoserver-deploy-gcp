#!/bin/bash

# Script to sync images from Quay.io to Artifact Registry

set -e

PROJECT_ID=${PROJECT_ID:-"cdr-discovery"}
REGION=${REGION:-"europe-west2"}
QUAY_USERNAME=${QUAY_USERNAME:-""}
QUAY_PASSWORD=${QUAY_PASSWORD:-""}

if [ -z "$QUAY_USERNAME" ] || [ -z "$QUAY_PASSWORD" ]; then
    echo "Error: QUAY_USERNAME and QUAY_PASSWORD environment variables must be set"
    exit 1
fi

echo "Syncing images to Artifact Registry..."

# Login to Quay.io
echo "$QUAY_PASSWORD" | docker login quay.io -u "$QUAY_USERNAME" --password-stdin

# Configure Docker for Artifact Registry
gcloud auth configure-docker $REGION-docker.pkg.dev

# Pull and push Ontoserver image
docker pull quay.io/aehrc/ontoserver:ctsa-6
docker tag quay.io/aehrc/ontoserver:ctsa-6 $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:ctsa-6
docker tag quay.io/aehrc/ontoserver:ctsa-6 $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:latest
docker push $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:ctsa-6
docker push $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:latest

echo "Image sync completed!"
