# GitHub Actions OIDC Setup for Azure Load Testing

This guide explains how to configure federated identity (OIDC) for secure authentication between GitHub Actions and Azure.

## Benefits of OIDC Authentication

✅ **No secret rotation** - No need to manage or rotate service principal secrets  
✅ **More secure** - No long-lived credentials stored in GitHub  
✅ **Automatic** - Azure AD verifies GitHub's identity using OpenID Connect  

## Setup Instructions

### 1. Create Azure AD Application and Service Principal

```bash
# Set variables
REPO_OWNER="Gwayaboy"
REPO_NAME="nodejs-appsvc-cosmosdb-bottleneck"
APP_NAME="gh-actions-${REPO_NAME}"

# Create Azure AD application
az ad app create --display-name "${APP_NAME}"

# Get the Application (client) ID
APP_ID=$(az ad app list --display-name "${APP_NAME}" --query "[0].appId" -o tsv)
echo "Application ID: ${APP_ID}"

# Create service principal
az ad sp create --id "${APP_ID}"

# Get the Object ID of the service principal
SP_OBJECT_ID=$(az ad sp list --filter "appId eq '${APP_ID}'" --query "[0].id" -o tsv)
echo "Service Principal Object ID: ${SP_OBJECT_ID}"
```

### 2. Configure Federated Credentials

```bash
# For main branch
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${REPO_OWNER}"'/'"${REPO_NAME}"':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# For pull requests (optional)
az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters '{
    "name": "github-actions-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"${REPO_OWNER}"'/'"${REPO_NAME}"':pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### 3. Assign Azure Permissions

```bash
# Set subscription and resource group
SUBSCRIPTION_ID="518d3b64-280a-4d38-8b93-ea7404fe5ea1"
RESOURCE_GROUP="kantar-demo-rg"
LOAD_TEST_RESOURCE="ALT-Kantar-Demo"

# Assign Contributor role to resource group
az role assignment create \
  --assignee "${APP_ID}" \
  --role "Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"

# Assign Load Test Contributor role (if available)
az role assignment create \
  --assignee "${APP_ID}" \
  --role "Load Test Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.LoadTestService/loadTests/${LOAD_TEST_RESOURCE}" \
  2>/dev/null || echo "Load Test Contributor role not available, Contributor role is sufficient"
```

### 4. Configure GitHub Secrets

Navigate to your GitHub repository: `https://github.com/Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck/settings/secrets/actions`

Add the following **Repository Secrets**:

```bash
# Get Tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

# Add secrets using GitHub CLI
gh secret set AZURE_CLIENT_ID --body "${APP_ID}"
gh secret set AZURE_TENANT_ID --body "${TENANT_ID}"
gh secret set AZURE_SUBSCRIPTION_ID --body "${SUBSCRIPTION_ID}"
```

Or add them manually in GitHub UI:

| Secret Name | Value |
|-------------|-------|
| `AZURE_CLIENT_ID` | Application (client) ID from step 1 |
| `AZURE_TENANT_ID` | Your Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Your Azure Subscription ID |

### 5. Configure GitHub Variables

Navigate to: `https://github.com/Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck/settings/variables/actions`

Add the following **Repository Variables**:

```bash
# Add variables using GitHub CLI
gh variable set LOAD_TEST_RESOURCE --body "ALT-Kantar-Demo"
gh variable set LOAD_TEST_RESOURCE_GROUP --body "kantar-demo-rg"
gh variable set LOAD_TEST_ID --body "sample-app-test"
gh variable set AZURE_WEBAPP_NAME --body "DemoBottleNeckWebApp"
```

Or add them manually in GitHub UI:

| Variable Name | Value |
|---------------|-------|
| `LOAD_TEST_RESOURCE` | ALT-Kantar-Demo |
| `LOAD_TEST_RESOURCE_GROUP` | kantar-demo-rg |
| `LOAD_TEST_ID` | sample-app-test |
| `AZURE_WEBAPP_NAME` | DemoBottleNeckWebApp |

## Verification

### Test the Setup

1. Push a commit to trigger the workflow:
   ```bash
   git commit --allow-empty -m "Test OIDC authentication"
   git push
   ```

2. Check the workflow run at:
   `https://github.com/Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck/actions`

3. Verify the "Login to Azure using OIDC" step succeeds

### Troubleshooting

**Error: "AADSTS70021: No matching federated identity record found"**
- Verify the federated credential subject matches exactly: `repo:Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck:ref:refs/heads/main`
- Check the issuer is: `https://token.actions.githubusercontent.com`

**Error: "403 Forbidden" when running load test**
- Verify the service principal has correct role assignments
- Check the resource group and load test resource names match

**Error: "Secret not found"**
- Ensure all three secrets are configured in GitHub
- Use exact names: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

## Security Best Practices

✅ Use repository variables for non-sensitive values (resource names, regions)  
✅ Use repository secrets for sensitive values (client ID, tenant ID, subscription ID)  
✅ Enable branch protection rules to prevent unauthorized workflow modifications  
✅ Regularly review service principal permissions and remove unused ones  
✅ Use environment-specific credentials for production workflows  

## References

- [Azure OIDC with GitHub Actions](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Azure Load Testing Documentation](https://learn.microsoft.com/en-us/azure/load-testing/)
