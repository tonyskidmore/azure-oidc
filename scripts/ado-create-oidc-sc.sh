#!/bin/bash

check_required_env_vars() {
  required_variables=("AZ_SUBSCRIPTION_ID" "AZ_SUBSCRIPTION_NAME" "AZ_TENANT_ID" "AZ_CLIENT_ID"
  "AZURE_DEVOPS_EXT_PAT" "AZDO_ORG_SERVICE_URL" "AZDO_PROJECT_NAME" "AZDO_PROJECT_ID"
  "AZDO_SERVICE_CONNECTION_NAME")

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

check_required_env_vars
sc_endpoint_data=$(envsubst < sc_endpoint_data.json)
printf "%s\n" "$sc_endpoint_data" | jq

curl \
  --show-error \
  --silent \
  --request POST \
  --user ":$AZURE_DEVOPS_EXT_PAT" \
  --header "Content-Type: application/json" \
  --data "$sc_endpoint_data" \
  "${AZDO_ORG_SERVICE_URL}/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
