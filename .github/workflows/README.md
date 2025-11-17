# GitHub Actions for Terraform

This directory contains GitHub Actions workflows and reusable actions for Terraform deployments.

## Overview

Simple Terraform CI/CD pipeline that handles:

- **Storage account firewall management** - Add/remove runner IP for state access
- **Terraform init** - Initialize with Azure backend
- **Terraform plan** - Generate and save execution plans
- **Terraform apply** - Apply infrastructure changes
- **Multi-environment support** - Runs for nonprod and prod

## Workflow

### `terraform-deploy.yml`

**Triggers:**
- Push to `main` branch
- Manual workflow dispatch

**Jobs:**

1. **Plan** - Runs terraform init and plan for both nonprod and prod environments
   - Adds runner IP to storage firewall
   - Initializes Terraform with Azure backend
   - Runs terraform plan
   - Uploads plan artifacts
   - Removes runner IP from storage firewall

2. **Apply** - Applies the plan (only on main branch)
   - Downloads plan artifacts
   - Re-initializes Terraform
   - Applies the saved plan
   - Requires approval for prod environment

## Actions

### `storage-firewall/`
Manages storage account firewall - adds/removes runner IP for state access.

### `terraform-state-check/`
Verifies access to Terraform state storage account.

### `terraform-init/`
Creates backend.tf and runs terraform init with Azure backend.

### `terraform-plan/`
Runs terraform plan, generates JSON/text output, copies config files.

### `terraform-apply/`
Applies the saved terraform plan.

### `terraform-destroy/`
Destroys infrastructure (use with caution).

## Setup

### 1. Create Azure Service Principal with OIDC

```bash
# Create app registration
APP_ID=$(az ad app create --display-name "GitHub-Actions-Terraform" --query appId -o tsv)

# Create service principal
az ad sp create --id $APP_ID
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query id -o tsv)

# Add federated credential
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:OWNER/REPO:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# Assign permissions
az role assignment create --assignee $SP_OBJECT_ID --role Contributor \
  --scope /subscriptions/NONPROD_SUB_ID

az role assignment create --assignee $SP_OBJECT_ID --role Contributor \
  --scope /subscriptions/PROD_SUB_ID

az role assignment create --assignee $SP_OBJECT_ID \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/TFSTATE_SUB_ID/resourceGroups/RG/providers/Microsoft.Storage/storageAccounts/SA
```

### 2. Configure GitHub Secrets

In repository **Settings > Secrets and variables > Actions**, add:

```
AZURE_CLIENT_ID=<App ID from step 1>
TENANT_ID=<Your Azure tenant ID>
TERRAFORM_VERSION=1.11.2
NONPROD_SUBSCRIPTION_ID=<Your nonprod subscription>
PROD_SUBSCRIPTION_ID=<Your prod subscription>
TFSTATE_SUBSCRIPTION_ID=<State storage subscription>
TFSTATE_RESOURCE_GROUP=<State storage resource group>
TFSTATE_STORAGE_ACCOUNT=<State storage account name>
TFSTATE_CONTAINER=tfstate
```

### 3. Configure GitHub Environments

1. **Settings > Environments > New environment**
2. Create `nonprod` - no protection rules
3. Create `prod` - add required reviewers and restrict to main branch

## Usage

Push to main branch or manually trigger the workflow to run plan and apply for both environments. Prod requires manual approval before apply.
