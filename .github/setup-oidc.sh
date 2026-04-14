#!/bin/bash

# Setup script for configuring GitHub Actions OIDC with Azure
# This script automates the Azure AD app registration and federated credential setup

set -e

echo "🚀 GitHub Actions OIDC Setup for Azure Load Testing"
echo "=================================================="
echo ""

# Variables
REPO_OWNER="Gwayaboy"
REPO_NAME="nodejs-appsvc-cosmosdb-bottleneck"
APP_NAME="gh-actions-${REPO_NAME}"
SUBSCRIPTION_ID="518d3b64-280a-4d38-8b93-ea7404fe5ea1"
RESOURCE_GROUP="kantar-demo-rg"
LOAD_TEST_RESOURCE="ALT-Kantar-Demo"

echo "Configuration:"
echo "  Repository: ${REPO_OWNER}/${REPO_NAME}"
echo "  Subscription: ${SUBSCRIPTION_ID}"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo "  Load Test Resource: ${LOAD_TEST_RESOURCE}"
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."
command -v az >/dev/null 2>&1 || { echo "❌ Azure CLI is required but not installed. Aborting." >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "❌ GitHub CLI is required but not installed. Aborting." >&2; exit 1; }
echo "✅ Prerequisites check passed"
echo ""

# Login check
echo "🔐 Checking Azure login..."
az account show >/dev/null 2>&1 || { echo "❌ Not logged in to Azure. Run 'az login' first." >&2; exit 1; }
echo "✅ Logged in to Azure"
echo ""

echo "🔐 Checking GitHub login..."
gh auth status >/dev/null 2>&1 || { echo "❌ Not logged in to GitHub. Run 'gh auth login' first." >&2; exit 1; }
echo "✅ Logged in to GitHub"
echo ""

# Step 1: Create Azure AD Application
echo "📝 Step 1: Creating Azure AD Application..."
az ad app create --display-name "${APP_NAME}" >/dev/null 2>&1 || echo "Application may already exist"

APP_ID=$(az ad app list --display-name "${APP_NAME}" --query "[0].appId" -o tsv)
if [ -z "${APP_ID}" ]; then
    echo "❌ Failed to create or find application"
    exit 1
fi
echo "✅ Application created: ${APP_ID}"
echo ""

# Step 2: Create Service Principal
echo "🔧 Step 2: Creating Service Principal..."
az ad sp create --id "${APP_ID}" >/dev/null 2>&1 || echo "Service principal may already exist"

SP_OBJECT_ID=$(az ad sp list --filter "appId eq '${APP_ID}'" --query "[0].id" -o tsv)
echo "✅ Service Principal created: ${SP_OBJECT_ID}"
echo ""

# Step 3: Configure Federated Credentials
echo "🔗 Step 3: Configuring Federated Credentials..."

# For main branch
echo "  Configuring federated credential for main branch..."
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${REPO_OWNER}"'/'"${REPO_NAME}"':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }' >/dev/null 2>&1 || echo "  Federated credential for main may already exist"

# For pull requests
echo "  Configuring federated credential for pull requests..."
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters '{
    "name": "github-actions-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${REPO_OWNER}"'/'"${REPO_NAME}"':pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }' >/dev/null 2>&1 || echo "  Federated credential for PRs may already exist"

echo "✅ Federated credentials configured"
echo ""

# Step 4: Assign Azure Permissions
echo "🔑 Step 4: Assigning Azure Permissions..."

echo "  Assigning Contributor role to resource group..."
az role assignment create \
  --assignee "${APP_ID}" \
  --role "Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}" \
  >/dev/null 2>&1 || echo "  Role assignment may already exist"

echo "✅ Permissions assigned"
echo ""

# Step 5: Get Tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

# Step 6: Configure GitHub Secrets
echo "🔐 Step 5: Configuring GitHub Secrets..."
echo "${APP_ID}" | gh secret set AZURE_CLIENT_ID -R "${REPO_OWNER}/${REPO_NAME}"
echo "${TENANT_ID}" | gh secret set AZURE_TENANT_ID -R "${REPO_OWNER}/${REPO_NAME}"
echo "${SUBSCRIPTION_ID}" | gh secret set AZURE_SUBSCRIPTION_ID -R "${REPO_OWNER}/${REPO_NAME}"
echo "✅ GitHub secrets configured"
echo ""

# Step 7: Configure GitHub Variables
echo "📊 Step 6: Configuring GitHub Variables..."
gh variable set LOAD_TEST_RESOURCE --body "${LOAD_TEST_RESOURCE}" -R "${REPO_OWNER}/${REPO_NAME}"
gh variable set LOAD_TEST_RESOURCE_GROUP --body "${RESOURCE_GROUP}" -R "${REPO_OWNER}/${REPO_NAME}"
gh variable set LOAD_TEST_ID --body "sample-app-test" -R "${REPO_OWNER}/${REPO_NAME}"
gh variable set AZURE_WEBAPP_NAME --body "DemoBottleNeckWebApp" -R "${REPO_OWNER}/${REPO_NAME}"
echo "✅ GitHub variables configured"
echo ""

# Summary
echo "=================================================="
echo "✅ Setup Complete!"
echo "=================================================="
echo ""
echo "Configuration Summary:"
echo "  Azure Application ID: ${APP_ID}"
echo "  Azure Tenant ID: ${TENANT_ID}"
echo "  Azure Subscription ID: ${SUBSCRIPTION_ID}"
echo ""
echo "GitHub Secrets Configured:"
echo "  ✅ AZURE_CLIENT_ID"
echo "  ✅ AZURE_TENANT_ID"
echo "  ✅ AZURE_SUBSCRIPTION_ID"
echo ""
echo "GitHub Variables Configured:"
echo "  ✅ LOAD_TEST_RESOURCE"
echo "  ✅ LOAD_TEST_RESOURCE_GROUP"
echo "  ✅ LOAD_TEST_ID"
echo "  ✅ AZURE_WEBAPP_NAME"
echo ""
echo "Next Steps:"
echo "  1. Verify configuration at:"
echo "     https://github.com/${REPO_OWNER}/${REPO_NAME}/settings/secrets/actions"
echo ""
echo "  2. Test the workflow by pushing a commit:"
echo "     git commit --allow-empty -m 'Test OIDC authentication'"
echo "     git push"
echo ""
echo "  3. Monitor the workflow at:"
echo "     https://github.com/${REPO_OWNER}/${REPO_NAME}/actions"
echo ""
