#!/bin/bash

# Ontoserver GCP Artifact Registry Setup Script
# This script sets up Artifact Registry and pulls Ontoserver image from Quay.io

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

print_status "Setting up Artifact Registry for project: $PROJECT_ID"
print_status "Region: $REGION"

# Set the project
gcloud config set project $PROJECT_ID

# Configure Docker to authenticate to Artifact Registry
print_status "Configuring Docker authentication for Artifact Registry..."
gcloud auth configure-docker $REGION-docker.pkg.dev

# Check if Quay.io credentials are available
if [ -z "$QUAY_USERNAME" ] || [ -z "$QUAY_PASSWORD" ]; then
    print_warning "Quay.io credentials not found in environment variables"
    print_warning "Please provide your Quay.io credentials to pull the Ontoserver image"
    read -p "Quay.io Username: " QUAY_USERNAME
    read -s -p "Quay.io Password: " QUAY_PASSWORD
    echo
fi

# Login to Quay.io
print_status "Logging in to Quay.io..."
echo "$QUAY_PASSWORD" | docker login quay.io -u "$QUAY_USERNAME" --password-stdin

# Pull and tag Ontoserver image
print_status "Pulling Ontoserver image from Quay.io..."
docker pull quay.io/aehrc/ontoserver:ctsa-6

# Tag the image for Artifact Registry
print_status "Tagging image for Artifact Registry..."
docker tag quay.io/aehrc/ontoserver:ctsa-6 $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:ctsa-6
docker tag quay.io/aehrc/ontoserver:ctsa-6 $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:latest

# Push the image to Artifact Registry
print_status "Pushing image to Artifact Registry..."
docker push $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:ctsa-6
docker push $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:latest

# Create a script to sync additional images if needed
print_status "Creating image sync script..."
cat > sync-images.sh << EOF
#!/bin/bash

# Script to sync images from Quay.io to Artifact Registry

set -e

PROJECT_ID=\${PROJECT_ID:-"$PROJECT_ID"}
REGION=\${REGION:-"$REGION"}
QUAY_USERNAME=\${QUAY_USERNAME:-""}
QUAY_PASSWORD=\${QUAY_PASSWORD:-""}

if [ -z "\$QUAY_USERNAME" ] || [ -z "\$QUAY_PASSWORD" ]; then
    echo "Error: QUAY_USERNAME and QUAY_PASSWORD environment variables must be set"
    exit 1
fi

echo "Syncing images to Artifact Registry..."

# Login to Quay.io
echo "\$QUAY_PASSWORD" | docker login quay.io -u "\$QUAY_USERNAME" --password-stdin

# Configure Docker for Artifact Registry
gcloud auth configure-docker \$REGION-docker.pkg.dev

# Pull and push Ontoserver image
docker pull quay.io/aehrc/ontoserver:ctsa-6
docker tag quay.io/aehrc/ontoserver:ctsa-6 \$REGION-docker.pkg.dev/\$PROJECT_ID/ontoserver-repo/ontoserver:ctsa-6
docker tag quay.io/aehrc/ontoserver:ctsa-6 \$REGION-docker.pkg.dev/\$PROJECT_ID/ontoserver-repo/ontoserver:latest
docker push \$REGION-docker.pkg.dev/\$PROJECT_ID/ontoserver-repo/ontoserver:ctsa-6
docker push \$REGION-docker.pkg.dev/\$PROJECT_ID/ontoserver-repo/ontoserver:latest

echo "Image sync completed!"
EOF

chmod +x sync-images.sh

print_status "Artifact Registry setup completed successfully!"
print_status ""
print_status "Images pushed to:"
print_status "- $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:ctsa-6"
print_status "- $REGION-docker.pkg.dev/$PROJECT_ID/ontoserver-repo/ontoserver:latest"
print_status ""
print_status "Next steps:"
print_status "1. Run: ./deploy-ontoserver.sh"
print_status ""
print_status "To sync images again in the future:"
print_status "QUAY_USERNAME=your-username QUAY_PASSWORD=your-password ./sync-images.sh" 