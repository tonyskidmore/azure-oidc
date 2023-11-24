#!/bin/bash

set -eo pipefail
PS4='LINENO:'

script_name=$(basename "${0}")
# shellcheck disable=SC2034
declare -A assoc_array

usage () {
  cat <<END

Usage : ${script_name} [-h] -a <oidc_app_name> [-d] [-e <entra_tenant_id>] [-f oidc_federated_credential_scenario ] -i <oidc_subject_identifier> [-f <oidc_federated_credential_scenario>] [-g <oidc_resource_group_name>] [-j <json_file_location>] [-l <oidc_resource_group_location>] [-n <oidc_subscription_name>] [-m <mode>] [-o <oidc_organization>] [-q] [-r <oidc_role_assignment>] [-s <oidc_subscription_id>] [-t <oidc_resource_group_tags>] [-u oidc_issuer_url] [-y]

  -a = Azure AD app registration name
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
  -o = Organization e.g. Azure DevOps organization name
  -q = quiet mode
  -r = Azure role assignment for OIDC scope
  -s = Azure subscription ID for OIDC
  -t = Azure resource group for OIDC tags
  -u = OIDC issuer URL
  -y = Answer yes to prompting to force deletion

Purpose:

  Create or delete an Azure AD app registration with federated credentials for OIDC

END
  exit 0
}

# set defaults
mode="${AZURE_OIDC_MODE:-create}"
oidc_federated_credential_scenario="${AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO:-GitHub}"
oidc_issuer_url="${AZURE_OIDC_ISSUER_URL:-https://token.actions.githubusercontent.com}"

while getopts "a:de:f:g:hj:i:l:m:n:o:r:s:t:qu:y" name
do
  case ${name} in
  a)
        # shellcheck disable=SC2034
        oidc_app_name="${OPTARG}"
        ;;
  d)
        # shellcheck disable=SC2034
        debug="true"
        ;;
  e)
        # shellcheck disable=SC2034
        entra_id_tenant_id="${OPTARG}"
        ;;
  f)
        # shellcheck disable=SC2034
        oidc_federated_credential_scenario="${OPTARG}"
        ;;
  g)
        # shellcheck disable=SC2034
        oidc_resource_group_name="${OPTARG}"
        ;;
  i)
        # shellcheck disable=SC2034
        oidc_subject_identifier="${OPTARG}"
        ;;
  j)
        # shellcheck disable=SC2034
        json_file_location="${OPTARG}"
        ;;
  l)
        # shellcheck disable=SC2034
        oidc_resource_group_location="${OPTARG}"
        ;;
  m)
        mode="${OPTARG}"
        if [[ "$mode" != "create" && "$mode" != "delete" ]]; then
          echo "Error: Invalid mode. Only 'create' or 'delete' are allowed."
          usage
        fi
        ;;
  n)
        # shellcheck disable=SC2034
        oidc_subscription_name="${OPTARG}"
        ;;
  o)
        # shellcheck disable=SC2034
        oidc_organization="${OPTARG}"
        ;;
  q)
        # shellcheck disable=SC2034
        quiet="true"
        ;;
  r)
        # shellcheck disable=SC2034
        oidc_role_assignment="${OPTARG}"
        ;;
  s)
        # shellcheck disable=SC2034
        oidc_subscription_id="${OPTARG}"
        ;;
  t)
        # shellcheck disable=SC2034
        oidc_resource_group_tags="${OPTARG}"
        ;;
  u)
        # shellcheck disable=SC2034
        oidc_issuer_url="${OPTARG}"
        ;;
  y)
        # shellcheck disable=SC2034
        yes="true"
        ;;
  h | *)
        usage
        ;;
  esac
done 2>/dev/null

for file in "$(dirname "${BASH_SOURCE[0]}")/bash_functions/"*.sh; do
  # shellcheck disable=SC1090
  source "$file"
done

# run function based on mode of operation
"${mode}_oidc_app"
