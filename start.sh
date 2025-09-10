#!/bin/bash

set -e

# Check if CORALOGIX_APIKEY is set
if [[ -z "${CORALOGIX_APIKEY}" ]]; then
  echo "Error: The environment variable CORALOGIX_APIKEY is not set."
  echo "Please set it using the command: export CORALOGIX_APIKEY=<your-api-key>"
  exit 1
fi

echo "Starting Minikube..."
minikube start --memory=16G --cpus=max
minikube addons enable metrics-server

echo "Waiting for Kubernetes to be ready..."
while [[ $(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
  echo "Kubernetes is not ready yet. Retrying in 5 seconds..."
  sleep 5
done

echo "Kubernetes is ready!"


# Create the 'coralogix-keys' secret
SECRET_NAME="coralogix-keys"
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
  echo "Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'."
else
  echo "Creating secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
  kubectl create secret generic "$SECRET_NAME" \
    --from-literal=PRIVATE_KEY="$CORALOGIX_APIKEY" \
    -n "$NAMESPACE"
  echo "Secret '$SECRET_NAME' created successfully."
fi

# Install cert-manager using Helm - needed for opentelemetry operator
helm repo add jetstack https://charts.jetstack.io 2>&1
helm repo update 2>&1

if kubectl get pods --no-headers | grep -q 'Running' > /dev/null 2>&1; then
  echo "Cert-manager install already done."
else
  echo "Installing cert-manager using Helm..."
  helm install cert-manager jetstack/cert-manager \
  --version v1.13.0 \
  --set installCRDs=true \
  --set admissionWebhooks.certManager.enabled=false \
  --set admissionWebhooks.autoGenerateCert.enabled=true

  echo "Waiting for cert-manager pods to be ready..."
  sleep 2
  kubectl wait \
  --for=condition=Ready pods \
  --all --timeout=300s

  echo "cert-manager installation complete!"
fi

helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual 2>&1
helm repo update 2>&1


if kubectl get pods | grep -q 'coralogix-otel-collector' > /dev/null 2>&1; then
  echo "Coralogix OpenTelemetry Collector install already done."
else
  echo "Installing the Coralogix OpenTelemetry Collector using Helm..."
  helm upgrade --install otel-coralogix-integration coralogix-charts-virtual/otel-integration \
    --render-subchart-notes \
    --set global.domain="eu2.coralogix.com" \
    --set global.clusterName="se-demo" \
    --set opentelemetry-cluster-collector.ports.otlp-http.enabled=true \
    -f cx-overrides.yaml
  sleep 2
  echo "Waiting for Coralogix OpenTelemetry Collector pods to be ready..."
  kubectl wait \
    --for=condition=Ready pods \
    --selector=app.kubernetes.io/instance=otel-coralogix-integration  \
    --timeout=300s
fi

# Add the OpenTelemetry Helm repository
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts 2>&1
helm repo update 2>&1


if kubectl get pods --no-headers | grep -q 'kafka' | grep -q 'Running' > /dev/null 2>&1; then
  echo "OpenTelemetry Demo install already done."
else
  echo "Installing the OpenTelemetry Demo using Helm..."
  helm upgrade --install my-otel-demo open-telemetry/opentelemetry-demo -f otel-demo-overrides.yaml

  echo "Waiting for OpenTelemetry Demo pods to be ready..."
  sleep 2
  kubectl wait \
  --for=condition=Ready pods \
  --selector=opentelemetry.io/name=kafka \
  --timeout=300s
fi

echo "OpenTelemetry Demo installation complete!"
