# Ontoserver Dockerfile for GCP Cloud Run
# Based on AEHRC Ontoserver deployment patterns
# https://github.com/aehrc/ontoserver-deploy/tree/master/docker

# Use the official Ontoserver image as base
FROM quay.io/aehrc/ontoserver:ctsa-6

# Set environment variables for Cloud Run
ENV SPRING_PROFILES_ACTIVE=cloud
ENV JAVA_OPTS="-Xmx2g -Xms1g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# Expose the FHIR server port
EXPOSE 8080

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/fhir/metadata || exit 1

# Default command (inherited from base image)
# The base image already has the correct CMD for starting Ontoserver 