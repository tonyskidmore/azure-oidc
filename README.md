# azure-oidc

Script to create Microsoft Entra ID application, service principal and federated credentials for use with OpenID Connect (OIDC).  

This enables GitHub Actions workflows to access Azure resources without storing long-lived Azure credentials in GitHub secrets.

The script has some limited RBAC capability e.g. you can define a resource group or subscription scope for the created app service principal.

## Requirements

### Azure
* Azure subscription  
  Create or delete:  
  Owner or Contributor + User Access Administrator  
  Read:  
  Reader  

* Microsoft Entra ID  
  Create or delete:  
  Global Administrator or Application Administrator  
  Read:  
  Directory Readers  

## Tools
* [Azure CLI](https://github.com/Azure/azure-cli) - created and tested with version 2.53.1
* [jq](https://stedolan.github.io/jq) - created and tested with version 1.6

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

# Create app with multiple RBAC on defined resource group and multiple federated credentials
./scripts/azure-oidc.sh \
  -a azure-github-oidc \
  -g rg-azure-github-oidc \
  -r Contributor \
  -i repo:tonyskidmore/azure-github-oidc:pull_request,repo:tonyskidmore/azure-oidc:ref:refs/heads/main,repo:tonyskidmore/azure-github-oidc:environment:dev,repo:tonyskidmore/azure-oidc:ref:refs/tags/v1.2.32

# prompted deletion of the app and resource group
./scripts/azure-oidc.sh \
  -a azure-github-oidc \
  -g rg-azure-github-oidc \
  -m delete

# unprompted deletion of the app and resource group
./scripts/azure-oidc.sh \
  -a azure-github-oidc-dr \
  -g rg-azure-github-oidc-dr \
  -m delete \
  -y

# use environment variables as opposed to command line arguments
export AZURE_OIDC_APP_NAME="azure-github-oidc"
export AZURE_RESOURCE_GROUP_NAME="rg-azure-github-oidc"
export AZURE_OIDC_SUBJECT_IDENTIFIER="repo:tonyskidmore/azure-oidc:environment:dev"
export AZURE_OIDC_ROLE_ASSIGNMENT="Contributor,Storage Blob Data Contributor"
./scripts/azure-oidc.sh

# unprompted deletion of the app and resource group using environment variables
export AZURE_OIDC_APP_NAME="azure-github-oidc"
export AZURE_RESOURCE_GROUP_NAME="rg-azure-oidc"
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
  -t "environment=dev cost_centre=123"

./scripts/azure-oidc.sh \
  -a azure-github-oidc \
  -g rg-azure-github-oidc \
  -r Reader \
  -i repo:tonyskidmore/azure-oidc:pull_request \
  -j "$PWD/pr-oidc-app.json" \
  -t "environment=dev cost_centre=123" \
  -q

````
## Azure DevOps examples (not yet implemented)

````bash

./scripts/azure-oidc.sh \
  -a azure-ado-oidc \
  -u https://vstoken.dev.azure.com/e1538f7b-5100-4fa8-8a72-5ea2518261e2 \
  -i "sc://tonyskidmore/oidc/azurerm-oidc"

````

## GitHub references

[Use GitHub Actions to connect to Azure](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-cli%2Clinux)  

[Configuring OpenID Connect in Azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)  

[GitHub Azure AD OIDC Authentication](https://www.youtube.com/watch?v=XkhkkLBkAT4)  

[Passwordless Github Actions with Azure Workload Identity OIDC](https://www.youtube.com/watch?v=7iCtY0ztYY4)  


## Azure and Azure DevOps references

[Workload identity federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)  

[Introduction to Azure DevOps Workload identity federation (OIDC) with Terraform](https://techcommunity.microsoft.com/t5/azure-devops-blog/introduction-to-azure-devops-workload-identity-federation-oidc/ba-p/3908687)  


## Terraform references

[Azure Provider: Authenticating using a Service Principal with Open ID Connect](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_oidc)  

[terraform-azuread-github_oidc](https://registry.terraform.io/modules/ned1313/github_oidc/azuread/latest)  

[azuredevops](https://registry.terraform.io/providers/microsoft/azuredevops/latest)  

[azuredevops_serviceendpoint_azurerm](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/serviceendpoint_azurerm#workload-identity-federation-manual-azurerm-service-endpoint-subscription-scoped)  

[Using Managed Identity or OIDC to Authenticate from Azure DevOps Pipelines to Azure for Terraform Deployments](https://github.com/Azure-Samples/azure-devops-terraform-oidc-ci-cd)  

[AzureCLI@2 task](https://github.com/Azure-Samples/azure-devops-terraform-oidc-ci-cd/blob/8f8c0073a145ddbcbcda2d67d4e9027e317a5c37/pipelines/oidc.yml#L81)  

## TODO
* add option for Azure DevOps
* further testing and tests
