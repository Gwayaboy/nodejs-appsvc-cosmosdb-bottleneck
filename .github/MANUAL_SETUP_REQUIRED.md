# Manual Step Required: Grant Subscription Access

## Issue
The automated setup script successfully created the Azure AD application and federated credentials, but requires a manual step to grant subscription-level access.

## Required Action

An administrator with **Owner** or **User Access Administrator** role on the subscription needs to run this command:

```bash
# Service Principal Details
APP_ID="10449910-1c62-4d19-923b-5879a24e8d1c"
SP_OBJECT_ID="28ca05ce-6960-4311-b0e7-335027248db5"
SUBSCRIPTION_ID="518d3b64-280a-4d38-8b93-ea7404fe5ea1"

# Assign Reader role at subscription level
az role assignment create \
  --assignee "${APP_ID}" \
  --role "Reader" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}"
```

## Why This Is Needed

The Azure CLI login action needs to:
1. Authenticate using OIDC (✅ Working)
2. Verify subscription access (❌ Needs Reader role)

Without the Reader role at subscription level, the workflow will fail with:
```
Error: No subscriptions found for ***.
```

## Alternative: Use Resource Group Scope Only

If subscription-level access cannot be granted, you can modify the workflow to skip subscription validation:

**Option 1: Add `allow-no-subscriptions` parameter:**

```yaml
- name: Login to Azure using OIDC
  uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    allow-no-subscriptions: true  # Add this line
```

**Option 2: Remove subscription-id and use resource group scope:**

```yaml
- name: Login to Azure using OIDC
  uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    # Remove subscription-id line

- name: Set Azure subscription
  run: |
    az account set --subscription ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

## Current Status

✅ Azure AD Application created  
✅ Federated credentials configured  
✅ Service Principal created  
✅ Contributor role assigned to resource group  
✅ GitHub secrets configured  
✅ GitHub variables configured  
❌ **Reader role at subscription level (manual step required)**  

## Once Completed

After granting the subscription access, trigger the workflow again:

```bash
git commit --allow-empty -m "Test OIDC with subscription access"
git push
```

Or manually trigger from GitHub Actions UI:
https://github.com/Gwayaboy/nodejs-appsvc-cosmosdb-bottleneck/actions/workflows/load-test.yml
