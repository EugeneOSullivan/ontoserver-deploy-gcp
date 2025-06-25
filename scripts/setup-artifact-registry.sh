#!/bin/bash

# Ontoserver Artifact Registry Setup Script
# This script pulls the Ontoserver image from Quay.io and pushes it to Artifact Registry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required environment variables are set
if [ -z "$PROJECT_ID" ]; then
    print_error "PROJECT_ID environment variable is not set"
    echo "Please set it with: export PROJECT_ID='your-project-id'"
    exit 1
fi

if [ -z "$REGION" ]; then
    print_warning "REGION not set, using default: europe-west2"
    export REGION="europe-west2"
fi

if [ -z "$QUAY_USERNAME" ] || [ -z "$QUAY_PASSWORD" ]; then
    print_error "QUAY_USERNAME and QUAY_PASSWORD environment variables are not set"
    echo "Please set them with:"
    echo "export QUAY_USERNAME='your-quay-username'"
    echo "export QUAY_PASSWORD='your-quay-password'"
    exit 1
fi

print_status "Setting up Artifact Registry for project: $PROJECT_ID"
print_status "Region: $REGION"

# Set the project
gcloud config set project $PROJECT_ID

# Configure Docker authentication for Artifact Registry
print_status "Configuring Docker authentication for Artifact Registry..."
gcloud auth configure-docker $REGION-docker.pkg.dev

# Login to Quay.io
print_status "Logging in to Quay.io..."
echo "$QUAY_PASSWORD" | docker login quay.io -u "$QUAY_USERNAME" --password-stdin

# Pull Ontoserver image from Quay.io
print_status "Pulling Ontoserver image from Quay.io..."
docker pull quay.io/aehrc/ontoserver:ctsa-6

# Tag image for Artifact Registry
print_status "Tagging image for Artifact Registry..."
docker tag quay.io/aehrc/ontoserver:ctsa-6 $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:latest

# Push image to Artifact Registry
print_status "Pushing image to Artifact Registry..."
docker push $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:latest

print_status "Artifact Registry setup completed successfully!"
print_status ""
print_status "Image pushed to: $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:latest"
print_status ""
print_status "Next steps:"
print_status "1. Run: ./deploy-ontoserver-k8s.sh" 