# Azure Load Testing with GitHub Actions - Showcase Guide

## 🎯 Overview

This repository demonstrates **Azure Load Testing integration with GitHub Actions** using **OpenID Connect (OIDC)** federated identity - the modern, secure approach that eliminates the need for storing service principal secrets.

## ✅ What's Configured

### 1. Azure Resources
- **App Service**: [DemoBottleNeckWebApp](https://demobottleneckwebapp.azurewebsites.net) (West US 2)
- **Cosmos DB**: demobottleneckwebappdb (MongoDB API)
- **Load Testing**: ALT-Kantar-Demo (East US, kantar-demo-rg)
- **Load Test ID**: sample-app-test

### 2. Azure AD Application (OIDC)
- **Application**: gh-actions-nodejs-appsvc-cosmosdb-bottleneck
- **Client ID**: 10449910-1c62-4d19-923b-5879a24e8d1c
- **Tenant ID**: 16b3c013-d300-468d-ac64-7eda0820b6d3
- **Subscription**: 518d3b64-280a-4d38-8b93-ea7404fe5ea1

### 3. Federated Credentials
Configured for:
- Main branch deployments: `repo:Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck:ref:refs/heads/main`
- Pull request validation: `repo:Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck:pull_request`

### 4. RBAC Permissions
The service principal has:
- **Reader** role at subscription level (for authentication)
- **Load Test Contributor** role on ALT-Kantar-Demo resource (for running tests)

### 5. GitHub Configuration
**Secrets** (encrypted):
- `AZURE_CLIENT_ID`: Application (client) ID
- `AZURE_TENANT_ID`: Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID`: Target subscription ID

**Variables** (plain text):
- `LOAD_TEST_RESOURCE`: ALT-Kantar-Demo
- `LOAD_TEST_RESOURCE_GROUP`: kantar-demo-rg
- `AZURE_WEBAPP_NAME`: DemoBottleNeckWebApp

## 🚀 How to Run

### Automatic Trigger
The workflow runs automatically on:
- Push to main branch
- Pull requests to main branch

### Manual Trigger
```bash
gh workflow run "Run Load Test" --repo Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck --ref main
```

Or use the GitHub UI:
1. Go to [Actions tab](https://github.com/Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck/actions)
2. Select "Run Load Test" workflow
3. Click "Run workflow"
4. Optionally provide custom values or use defaults

## 🔐 Security Highlights

### Why OIDC?
- ✅ **No secrets to rotate**: Uses short-lived tokens from GitHub
- ✅ **Reduced attack surface**: No long-lived credentials stored
- ✅ **Better audit trail**: Token requests logged in Azure AD
- ✅ **Microsoft recommended**: Industry best practice

### Traditional vs OIDC Approach

**❌ Traditional (Service Principal Secrets)**
```yaml
- uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}  # Contains clientSecret
```
*Requires storing and rotating client secrets*

**✅ OIDC (Federated Identity)**
```yaml
- uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    allow-no-subscriptions: true
```
*No secrets - GitHub provides OIDC token*

## 📊 Load Test Configuration

The load test is defined in [SampleApp.yaml](../SampleApp.yaml):
- **Test Script**: SampleApp.jmx (JMeter)
- **Engine Instances**: 1
- **Target**: ${webapp} environment variable
- **Duration**: Configured in JMeter script

## 🛠️ Workflow Architecture

### `.github/workflows/load-test.yml`
```yaml
name: Run Load Test
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      testId:
        description: 'Load Test ID'
        required: false
        default: 'sample-app-test'
      webappName:
        description: 'Web App Name'
        required: false

permissions:
  id-token: write    # Required for OIDC token request
  contents: read

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      # OIDC Authentication
      - name: Azure Login (OIDC)
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          allow-no-subscriptions: true
      
      # Explicitly set subscription
      - name: Set Azure Subscription
        run: az account set --subscription ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      # Run load test
      - name: Run Load Test
        uses: azure/load-testing@v1
        with:
          loadtestConfigFile: 'SampleApp.yaml'
          loadtestResource: ${{ vars.LOAD_TEST_RESOURCE }}
          resourceGroup: ${{ vars.LOAD_TEST_RESOURCE_GROUP }}
          env: |
            [
              {
              "name": "webapp",
              "value": "${{ github.event.inputs.webappName || vars.AZURE_WEBAPP_NAME }}.azurewebsites.net"
              }
            ]
```

## 📝 Key Learnings

### 1. OIDC Setup Considerations
- Service principal needs **Reader** at subscription level (not just resource group)
- Federated credentials must exactly match repository path and branch
- Use `allow-no-subscriptions: true` and set subscription explicitly after login

### 2. Load Testing Permissions
- **Load Test Contributor** role required on the load testing resource
- Assign at resource level, not resource group level
- Role assignment can take 1-2 minutes to propagate

### 3. Azure REST API for RBAC
When `az role assignment create` fails with permission issues, use REST API:
```bash
az rest --method PUT \
  --url "https://management.azure.com/{scope}/providers/Microsoft.Authorization/roleAssignments/{guid}?api-version=2022-04-01" \
  --body "{\"properties\":{\"roleDefinitionId\":\"{roleDefId}\",\"principalId\":\"{spObjectId}\",\"principalType\":\"ServicePrincipal\"}}"
```

## 📚 Resources

- [Azure Load Testing Documentation](https://learn.microsoft.com/azure/load-testing/)
- [GitHub Actions OIDC with Azure](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Tutorial: Identify Bottlenecks](https://learn.microsoft.com/azure/load-testing/tutorial-identify-bottlenecks-azure-portal)
- [Azure Load Testing GitHub Action](https://github.com/azure/load-testing)

## 🎬 Demo Script

### For Live Demonstration:
1. **Show the workflow file** (`.github/workflows/load-test.yml`)
   - Highlight OIDC authentication (no secrets in workflow)
   - Show permissions block (`id-token: write`)
   - Explain federated identity concept

2. **Show GitHub secrets/variables**
   ```bash
   gh secret list --repo Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck
   gh variable list --repo Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck
   ```
   - Note: Only IDs stored, no client secrets

3. **Trigger workflow manually**
   ```bash
   gh workflow run "Run Load Test" --repo Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck --ref main
   ```

4. **Monitor execution**
   ```bash
   gh run list --repo Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck --workflow="Run Load Test" --limit 1
   gh run watch <run-id> --repo Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck
   ```

5. **Show Azure Portal**
   - Navigate to ALT-Kantar-Demo load testing resource
   - Show test runs and results
   - Highlight metrics and bottleneck identification

## 🔍 Troubleshooting

### "No subscriptions found" error
✅ **Solution**: Add `allow-no-subscriptions: true` and explicitly set subscription

### "Subscription doesn't exist" error
✅ **Solution**: Grant Reader role at subscription level (not just resource group)

### "Insufficient permissions" error
✅ **Solution**: Assign Load Test Contributor role on the load testing resource

### Role assignment failures
✅ **Solution**: Use Azure REST API instead of `az role assignment create`

## ✨ Success Criteria

- [x] OIDC authentication configured (no client secrets)
- [x] Federated credentials for main branch and PRs
- [x] Service principal has subscription Reader access
- [x] Service principal has Load Test Contributor on resource
- [x] GitHub secrets and variables configured
- [x] Workflow executes successfully
- [x] Load test runs and completes
- [x] Results visible in Azure Portal

---

**Repository**: [Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck](https://github.com/Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck)  
**Load Testing Resource**: ALT-Kantar-Demo (East US)  
**Application**: https://demobottleneckwebapp.azurewebsites.net
