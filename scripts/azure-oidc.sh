#!/bin/bash

set -eo pipefail
PS4='LINENO:'

script_name=$(basename "${0}")
# shellcheck disable=SC2034
declare -A assoc_array

usage () {
  cat <<END

Usage : ${script_name} [-h] -a <oidc_app_name> [-d] -e <entra_tenant_id> -i <oidc_subject_identifier> [-f <oidc_federated_credential_scenario>] [-g <oidc_resource_group_name>] [-j <json_file_location>] [-l <oidc_resource_group_location>] -m <mode> [-r <oidc_role_assignment>] [-t <oidc_resource_group_tags>] [-q] [-y]

  -a = Azure AD app registration name
  -d = debug mode
  -e = Entra Tenant ID
  -i = OIDC subject identifier
  -f = Federated credential scenario
  -g = Azure resource group for OIDC RBAC assignment
  -h = Show help and usage
  -j = JSON output file location
  -l = Azure location for OIDC resource group
  -m = Mode of operation
  -r = Azure role assignment for OIDC scope
  -t = Azure resource group for OIDC tags
  -q = quiet mode
  -y = Answer yes to prompting to force deletion

Purpose:

  Create or delete an Azure AD app registration with federated credentials for OIDC

END
  exit 0
}

mode="${AZURE_OIDC_MODE:-create}"
oidc_federated_credential_scenario="GitHub"

while getopts "a:de:f:g:hj:i:l:m:r:s:t:qy" name
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
  r)
        # shellcheck disable=SC2034
        oidc_role_assignment="${OPTARG}"
        ;;
  s)
        # shellcheck disable=SC2034
        oidc_subscription="${OPTARG}"
        ;;
  t)
        # shellcheck disable=SC2034
        oidc_resource_group_tags="${OPTARG}"
        ;;
  q)
        # shellcheck disable=SC2034
        quiet="true"
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
