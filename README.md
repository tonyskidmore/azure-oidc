# azure-oidc

Script to create Microsoft Entra ID application, service principal and federated credentials for use with OpenID Connect (OIDC).  
This can be a helper when needing to create service principals in Entra ID that you need to run in a different security context to your Infrastructure as Code workflow i.e. which has no/limited access to Entra ID.

This enables GitHub Actions workflows to access Azure resources without storing long-lived Azure credentials in GitHub secrets, it can also be used with Azure DevOps.

The script has some limited RBAC capability e.g. you can define a resource group or subscription scope for the created app service principal.

## Requirements

### Azure

**Azure subscription**  
  _Create or delete:_  
  Owner or Contributor + User Access Administrator  
  _Read:_  
  Reader  

**Microsoft Entra ID**  
  _Create or delete:_  
  Global Administrator or Application Administrator  
  _Read:_  
  Directory Readers  

### Tools

* [Azure CLI](https://github.com/Azure/azure-cli) - created and tested with version 2.53.1
* [jq](https://stedolan.github.io/jq) - created and tested with version 1.6

The `ado-create-oidc-sc.sh` script additionally requires:

* [envsubst](https://www.man7.org/linux/man-pages/man1/envsubst.1.html) - which is part of the gettext package

### Syntax

````bash

scripts/azure-oidc.sh -h

Usage : azure-oidc.sh [-h] -a <oidc_app_name> [-c <oidc_service_connection_name>] [-d] [-e <entra_tenant_id>] [-f oidc_federated_credential_scenario ] -i <oidc_subject_identifier> [-f <oidc_federated_credential_scenario>] [-g <oidc_resource_group_name>] [-j <json_file_location>] [-l <oidc_resource_group_location>] [-n <oidc_subscription_name>] [-m <mode>] [-o <oidc_organization>] [-p <oidc_project_name>] [-q] [-r <oidc_role_assignment>] [-s <oidc_subscription_id>] [-t <oidc_resource_group_tags>] [-u oidc_issuer_url] [-v <oidc_vstoken_ado_org_id>] [-y]

  -a = Azure AD app registration name
  -b = debug output file location
  -c = Azure DevOps service connection name
  -d = debug mode
  -e = Entra Tenant ID - defalts to current subscription
  -f = Federated credential scenario - defaluts to GitHub
  -g = Azure resource group for OIDC RBAC assignment
  -h = Show help and usage
  -i = OIDC subject identifier
  -j = JSON output file location
  -l = Azure location for OIDC resource group
  -m = Mode of operation - defaults to "create"
  -n = Azure subscription name for OIDC
  -o = Organization e.g. Azure DevOps organization URL
  -p = Project e.g. Azure DevOps project name
  -q = quiet mode
  -r = Azure role assignment for OIDC scope
  -s = Azure subscription ID for OIDC
  -t = Azure resource group tags
  -u = OIDC issuer URL
  -v = Azure DevOps organization ID, for vstoken issuer URL
  -y = Answer yes to prompting to force deletion

Purpose:

  Create or delete an Azure AD app registration with federated credentials for OIDC

````

## GitHub examples

````bash

# Login to Azure first
az login
# set to the target subscription if necessary
# az account set --subscription <subscription_id>

# Create app with no RBAC or federated credentials - not much use
./scripts/azure-oidc.sh -o azure-github-oidc

# Create app with no RBAC or federated credentials and create a resource group - not much use
./scripts/azure-oidc.sh \
  -a azure-github-oidc \
  -g rg-azure-github-oidc

# Create app with single federated credential and no RBAC
./scripts/azure-oidc.sh \
  -a azure-github-oidc \
  -i "repo:tonyskidmore/azure-oidc:environment:dev"

# Doesn't allow for incorrect entries subject identifier or issuer URL
./scripts/azure-oidc.sh \
  -a azure-github-oidc-test \
  -i "rep:tonyskidmore/azure-oidc:environment:dev" \
  -u https://token.action.githubusercontent.com

# Create resource group and app an assign reader RBAC and create tags
# used for .github/workflows/github-oidc-test.yml
./scripts/azure-oidc.sh \
  -a azure-github-oidc-test \
  -g rg-azure-github-oidc-test \
  -r "Reader" \
  -i "repo:tonyskidmore/azure-oidc:environment:dev" \
  -t "environment=dev cost_centre=123"

# Create app and resource group with single RBAC and single federated credentials
./scripts/azure-oidc.sh \
  -a azure-github-oidc \
  -g rg-azure-github-oidc \
  -r "Contributor" \
  -i "repo:tonyskidmore/azure-oidc:environment:dev"

# Create app with single RBAC on defined resource group and federated credentials in an alternative Azure location with tags
./scripts/azure-oidc.sh \
  -a azure-github-oidc-dr \
  -g rg-azure-github-oidc-dr \
  -r "Contributor" \
  -i "repo:tonyskidmore/azure-github-oidc:environment:dev" \
  -t "environment=DR" \
  -l ukwest

# unprompted deletion of the app and resource group
./scripts/azure-oidc.sh \
  -a azure-github-oidc-dr \
  -g rg-azure-github-oidc-dr \
  -m delete \
  -y

# Create app with multiple RBAC on defined resource group and multiple federated credentials
./scripts/azure-oidc.sh \
  -a azure-github-oidc \
  -g rg-azure-github-oidc \
  -r Contributor \
  -i repo:tonyskidmore/azure-github-oidc:pull_request,repo:tonyskidmore/azure-oidc:ref:refs/heads/main,repo:tonyskidmore/azure-github-oidc:environment:dev,repo:tonyskidmore/azure-oidc:ref:refs/tags/v1.2.32

# use environment variables as opposed to command line arguments
export AZURE_OIDC_APP_NAME="azure-github-oidc"
export AZURE_RESOURCE_GROUP_NAME="rg-azure-github-oidc"
export AZURE_OIDC_SUBJECT_IDENTIFIER="repo:tonyskidmore/azure-oidc:environment:dev"
export AZURE_OIDC_ROLE_ASSIGNMENT="Contributor,Storage Blob Data Contributor"
./scripts/azure-oidc.sh

# unprompted deletion of the app and resource group using environment variables
export AZURE_OIDC_APP_NAME="azure-github-oidc"
export AZURE_RESOURCE_GROUP_NAME="rg-azure-github-oidc"
export AZURE_OIDC_MODE="delete"
export AZURE_OIDC_YES_FLAG="true"
./scripts/azure-oidc.sh

# run multiple times to set RBAC and produce JSON output
./scripts/azure-oidc.sh \
  -a azure-github-oidc \
  -g rg-azure-github-oidc \
  -r "Contributor" \
  -i "repo:tonyskidmore/azure-oidc:environment:dev" \
  -j "$PWD/dev-oidc-app.json" \
  -t "environment=dev cost_centre=123" \
  -d

./scripts/azure-oidc.sh \
  -a azure-github-oidc \
  -g rg-azure-github-oidc \
  -r Reader \
  -i repo:tonyskidmore/azure-oidc:pull_request \
  -j "$PWD/pr-oidc-app.json" \
  -t "environment=dev cost_centre=123" \
  -q

# prompted deletion of the app and resource group
./scripts/azure-oidc.sh \
  -a azure-github-oidc \
  -g rg-azure-github-oidc \
  -m delete

````

## Azure DevOps examples

> Workload identity federation for Azure Resource Manager is now [generally available](https://devblogs.microsoft.com/devops/workload-identity-federation-for-azure-deployments-is-now-generally-available/).

See: [Manually configure Azure Resource Manager workload identity service connections](https://learn.microsoft.com/en-us/azure/devops/pipelines/release/configure-workload-identity?view=azure-devops)  

| Field	             | Description                                                                            |
|--------------------|----------------------------------------------------------------------------------------|
| Issuer	           | Enter https://app.vstoken.visualstudio.com/_azure-devops-organization-guid_            |
| Subject identifier | Specify sc://_azure-devops-organization_/_project-name_/_service-connection-name_      |
|                    | You do not need to have created the service connection.                                |

````bash

# Create app with federated credential and no resource group or RBAC
./scripts/azure-oidc.sh \
  -a azure-ado-oidc \
  -u https://vstoken.dev.azure.com/e1538f7b-5100-4fa8-8a72-5ea2518261e2 \
  -i sc://tonyskidmore/oidc/azurerm-oidc \
  -f AzureDevOps

# Doesn't allow for incorrect entries subject identifier or issuer URL
./scripts/azure-oidc.sh \
  -a azure-ado-oidc-test \
  -u https://vstoken.dev.azure.com/e1538f7b-5100-4fa8-8a72-5ea2518261e \
  -i sc://tonyskidmore/oidc \
  -f AzureDevOps

# Create app with federated credential
# app registration named app-azure-ado-oidc
# issuer url for vstoken.dev.azure.com and the ADO org ID
# specify the subject identifier for the ADO org, project and service connection name
# specify a resource group and RBAC to assign
# use the AzureDevOps federation subject scenario
# create tags on the resource group
# output as JSON (screen and file)
# use debug output
./scripts/azure-oidc.sh \
  -a azure-ado-oidc \
  -u https://vstoken.dev.azure.com/e1538f7b-5100-4fa8-8a72-5ea2518261e2 \
  -i sc://tonyskidmore/oidc/azurerm-oidc \
  -g rg-azure-ado-oidc \
  -r Contributor \
  -f AzureDevOps \
  -t "environment=dev iac=az-cli" \
  -j ado-oidc-app.json \
  -o https://dev.azure.com/tonyskidmore \
  -p oidc \
  -d \
  -b "$PWD/log.txt"

# same as above but just specify the ADO org ID rather than the issuer url
# -i is constructed and not passed when -o, -p and -c are present
# the -u issuer URL can be constructed dynamically but only if
# a valid AZURE_DEVOPS_EXT_PAT is set AND is created with access to "All accessible organizations"
# export AZURE_DEVOPS_EXT_PAT="<pat-token>" is required to perform organization ID query
./scripts/azure-oidc.sh \
  -a azure-ado-oidc \
  -o https://dev.azure.com/tonyskidmore\
  -p oidc \
  -c azurerm-oidc \
  -g rg-azure-ado-oidc \
  -r Contributor \
  -f AzureDevOps \
  -t "environment=dev iac=az-cli" \
  -j ado-oidc-app.json \
  -d \
  -b "$PWD/log.txt"

 # read JSON and export all values
 # get AZ_PROJECT_ID from AZ_PROJECT_NAME
 # get org name by url and construct -i
 # -i sc://tonyskidmore/oidc/azurerm-oidc \


# PAT with scopes of at least Service Connections - Read, query & manage
# export AZURE_DEVOPS_EXT_PAT="<pat-token>"

# Create a "Workload Identity federation (manual)" service connection in Azure DevOps
# using the output of the ./scripts/azure-oidc.sh script above
scripts/ado-create-oidc-sc.sh ./ado-oidc-app.json


# delete the app and the resource group
./scripts/azure-oidc.sh \
  -a app-azure-ado-oidc \
  -g rg-azure-ado-oidc \
  -m delete

# vmss resource group
./scripts/azure-oidc.sh \
  -a vmss-ado-oidc \
  -u https://vstoken.dev.azure.com/e1538f7b-5100-4fa8-8a72-5ea2518261e2 \
  -g rg-vmss-win-001 \
  -r Contributor \
  -f AzureDevOps \
  -t "environment=dev iac=az-cli" \
  -j vmss-ado-oidc-app.json \
  -o https://dev.azure.com/tonyskidmore \
  -p win-vmss \
  -c azurerm-oidc \
  -d \
  -b "$PWD/log.txt"

scripts/ado-create-oidc-sc.sh ./vmss-ado-oidc-app.json

# delete the app and the resource group
./scripts/azure-oidc.sh \
  -a vmss-ado-oidc \
  -g rg-vmss-win-001 \
  -m delete

````

Create an OIDC connection to be used with `terraform-azurerm-vmss` and `terraform-azuredevops-elasticpool` Terraform modules.

````bash

# first create VMSS using: https://github.com/tonyskidmore/terraform-azurerm-vmss/tree/main/examples/admin_password

./scripts/azure-oidc.sh \
  -a vmss-ado-oidc \
  -u https://vstoken.dev.azure.com/e1538f7b-5100-4fa8-8a72-5ea2518261e2 \
  -g rg-tests-terraform-azurerm-vmss \
  -r Contributor \
  -f AzureDevOps \
  -t "environment=dev iac=az-cli" \
  -j vmss-ado-oidc-app.json \
  -o https://dev.azure.com/tonyskidmore \
  -p devops-vmss \
  -c azurerm-sc

scripts/ado-create-oidc-sc.sh ./vmss-ado-oidc-app.json

./scripts/azure-oidc.sh \
  -a vmss-ado-oidc \
  -g rg-vmss-win-001 \
  -m delete

````


## GitHub references

[Use GitHub Actions to connect to Azure](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-cli%2Clinux)  

[Configuring OpenID Connect in Azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)  

[GitHub Azure AD OIDC Authentication](https://www.youtube.com/watch?v=XkhkkLBkAT4)  

[Passwordless Github Actions with Azure Workload Identity OIDC](https://www.youtube.com/watch?v=7iCtY0ztYY4)  

## Azure and Azure DevOps references

[Manually configure Azure Resource Manager workload identity service connections](https://learn.microsoft.com/en-us/azure/devops/pipelines/release/configure-workload-identity?view=azure-devops)  

[Workload identity federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)  

[Introduction to Azure DevOps Workload identity federation (OIDC) with Terraform](https://techcommunity.microsoft.com/t5/azure-devops-blog/introduction-to-azure-devops-workload-identity-federation-oidc/ba-p/3908687)  

[Use service principals & managed identities](https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/service-principal-managed-identity?view=azure-devops)  

[Service Principal Entitlements](https://learn.microsoft.com/en-us/rest/api/azure/devops/memberentitlementmanagement/service-principal-entitlements?view=azure-devops-rest-7.1&preserve-view=true)  

## Terraform references

[Azure Provider: Authenticating using a Service Principal with Open ID Connect](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_oidc)  

[terraform-azuread-github_oidc](https://registry.terraform.io/modules/ned1313/github_oidc/azuread/latest)  

[azuredevops](https://registry.terraform.io/providers/microsoft/azuredevops/latest)  

[azuredevops_serviceendpoint_azurerm](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/serviceendpoint_azurerm#workload-identity-federation-manual-azurerm-service-endpoint-subscription-scoped)  

[Using Managed Identity or OIDC to Authenticate from Azure DevOps Pipelines to Azure for Terraform Deployments](https://github.com/Azure-Samples/azure-devops-terraform-oidc-ci-cd)  

[AzureCLI@2 task](https://github.com/Azure-Samples/azure-devops-terraform-oidc-ci-cd/blob/8f8c0073a145ddbcbcda2d67d4e9027e317a5c37/pipelines/oidc.yml#L81)  

## TODO

* Add support for User Assigned Managed Identity
* Mention using without PAT
* further testing and tests
