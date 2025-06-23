# Multi-stage build to handle Quay.io authentication
FROM alpine:latest as image-puller

# Install curl for health checks
RUN apk add --no-cache curl

# Use the Ontoserver image from Artifact Registry (pushed via setup script)
# Note: This Dockerfile is used for local builds or custom modifications
# For production, use the image directly from Artifact Registry
FROM quay.io/aehrc/ontoserver:ctsa-6

# Set environment variables for Cloud Run
ENV SPRING_PROFILES_ACTIVE=cloud
ENV JAVA_OPTS="-Xmx2g -Xms1g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
ENV PORT=8080

# Expose port 8080 (Cloud Run requirement)
EXPOSE 8080

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/fhir/metadata || exit 1

# The base image already has the correct entrypoint and command
# Cloud Run will automatically handle the port binding to $PORT 