#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="smtp-relay-rg"
CONTAINER_NAME="smtp-relay"
LOCATION="westeurope"
DNS_LABEL="smtp-relay"
ACR_NAME="smtprelaycr"
IDENTITY_NAME="smtp-relay-identity"

IMAGE="${ACR_NAME}.azurecr.io/smtp-relay"
VERSION=$(date -u +"%Y%m%d-%H%M%S")
VERSIONED_IMAGE="${IMAGE}:${VERSION}"

echo "==> Creating resource group (if not exists)..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

echo "==> Creating ACR (if not exists)..."
az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Basic --location "$LOCATION" --output none 2>/dev/null || true

echo "==> Creating managed identity (if not exists)..."
az identity create --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --output none 2>/dev/null || true

IDENTITY_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query id --output tsv | tr -d '\r')
IDENTITY_PRINCIPAL_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query principalId --output tsv | tr -d '\r')
ACR_ID=$(az acr show --name "$ACR_NAME" --query id --output tsv | tr -d '\r')

echo "==> Granting AcrPull to managed identity (if not already assigned)..."
az role assignment create \
  --assignee "$IDENTITY_PRINCIPAL_ID" \
  --role AcrPull \
  --scope "$ACR_ID" \
  --output none 2>/dev/null || true

echo "==> Logging in to ACR..."
az acr login --name "$ACR_NAME"

echo "==> Building Docker image (${VERSION})..."
docker build -t "$VERSIONED_IMAGE" -t "${IMAGE}:latest" .

echo "==> Pushing to ACR..."
docker push "$VERSIONED_IMAGE"
docker push "${IMAGE}:latest"

echo "==> Deleting existing container (if exists)..."
az container delete --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_NAME" --yes --output none 2>/dev/null || true

echo "==> Deploying to Azure Container Instances..."
az container create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CONTAINER_NAME" \
  --image "$VERSIONED_IMAGE" \
  --os-type Linux \
  --cpu 0.5 \
  --memory 0.5 \
  --ports 587 \
  --protocol TCP \
  --dns-name-label "$DNS_LABEL" \
  --assign-identity "$IDENTITY_ID" \
  --acr-identity "$IDENTITY_ID" \
  --environment-variables SMTP_DOMAIN="${DNS_LABEL}.${LOCATION}.azurecontainer.io" \
  --output none

FQDN=$(az container show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CONTAINER_NAME" \
  --query ipAddress.fqdn \
  --output tsv | tr -d '\r')

echo ""
echo "==> Deployed successfully!"
echo "    Image:  $VERSIONED_IMAGE"
echo "    FQDN:   $FQDN"
echo "    Port:   587"
echo ""
echo "    Test with:  swaks --to test@example.com --from sender@example.com --server $FQDN --port 587"
echo "    View logs:  az container logs -g $RESOURCE_GROUP -n $CONTAINER_NAME --follow"
