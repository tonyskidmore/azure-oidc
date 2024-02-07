#!/bin/bash

set -eo pipefail
PS4='LINENO:'

check_required_env_vars() {
  required_variables=("AZ_SUBSCRIPTION_ID" "AZ_SUBSCRIPTION_NAME" "AZ_TENANT_ID" "AZ_CLIENT_ID"
  "AZURE_DEVOPS_EXT_PAT" "AZDO_ORG_SERVICE_URL" "AZ_PROJECT_NAME" "AZ_PROJECT_ID" "AZ_SERVICE_CONNECTION_NAME")

  for i in "${required_variables[@]}"
  do
      if [[ ! "${i,,}" =~ (token)|(key)|(secret)|(pat) ]]
      then
        printf "%s: %s\n" "$i" "${!i}"
      else
        printf "%s: <redacted>\n" "$i"
      fi
      if [[ -z "${!i}" ]]
      then
        echo "Value for $i cannot be empty"
        exit 1
      fi
  done
}

# shellcheck disable=SC1091
source "scripts/bash_functions/json-functions.sh"
# shellcheck disable=SC1091
source "scripts/bash_functions/ado-rest-api-functions.sh"
# shellcheck disable=SC1091
source "scripts/bash_functions/general-functions.sh"

# exit_code=0
# http_exit_code=0
# http_code=0

# printf "%s\n" "$sc_endpoint_data"
# json=$(<"./ado-oidc-app.json")
json=$(<"$1")
jq_json_to_env_vars "$json"
# jq_json_to_env_vars "$1"
echo "$AZ_PROJECT_NAME"
project_id=$(get_ado_project_id_by_name "$AZ_PROJECT_NAME")

printf "%s\n" "$project_id"
printf "out:\n %s\n" "$out"
printf "http_exit_code: %s\n" "$HTTP_EXIT_CODE"
printf "http_code: %s\n" "$HTTP_CODE"
printf "exit_code: %s\n" "$EXIT_CODE"
export AZ_PROJECT_ID="$project_id"
sc_endpoint_data=$(envsubst < scripts/ado-create-oidc-sc.json)
printf "%s\n" "$sc_endpoint_data"

ado_service_connection=$(create_ado_service_endpoint "$sc_endpoint_data")
debug_output "$LINENO" "ado_service_connection" "$ado_service_connection"
