#!/bin/bash

create_az_ad_app() {
  local az_ad_app_display_name="$1"

  az ad app create \
    --display-name "$az_ad_app_display_name" \
    --output json
}

create_az_ad_app_fed_cred() {
  local az_ad_app_id="$1"
  local fed_cred_params="$2"

  az ad app federated-credential create \
      --id "$az_ad_app_id" \
      --parameters "$fed_cred_params" \
      --output json
}

create_az_ad_sp() {
  local az_ad_app_id="$1"

  az ad sp create \
    --id "$az_ad_app_id" \
    --output json

}

create_az_group() {
  local az_resource_group_name="$1"
  local az_resource_group_location="${2:-uksouth}"
  shift 2
  local az_resource_group_tags_string="$*"
  local tag_string=""

  IFS=' ' read -r -a az_resource_group_tags_array <<< "$az_resource_group_tags_string"

  # Build tag string for Azure CLI
  for tag_pair in "${az_resource_group_tags_array[@]}"; do
    if [[ "$tag_pair" == *"="* ]]; then
      tag_string+="$tag_pair "
    fi
  done

  az group create \
    --name "$az_resource_group_name" \
    --location "$az_resource_group_location" \
    --tags "${az_resource_group_tags_array[@]}" \
    --output json
}

create_az_identity() {
  local az_identity_name="$1"
  local az_resource_group_name="$2"
  local az_identity_location="${3:-uksouth}"
  shift 2
  local az_identity_tags_string="$*"
  local tag_string=""

  IFS=' ' read -r -a az_identity_tags_array <<< "$az_identity_tags_string"

  # Build tag string for Azure CLI
  for tag_pair in "${az_identity_tags_array[@]}"; do
    if [[ "$tag_pair" == *"="* ]]; then
      tag_string+="$tag_pair "
    fi
  done

  az identity create \
    --name "$az_identity_name" \
    --resource-group "$az_resource_group_name" \
    --location "$az_identity_location" \
    --tags "${az_resource_group_tags_array[@]}" \
    --output json
}

create_az_ad_identity_fed_cred() {
  local identity_name="$1"
  local name="$2"
  local az_resource_group_name="$3"
  local issuer="$4"
  local subject="$5"

  az ad app federated-credential create \
      --identity-name "$identity_name" \
      --name "$name" \
      --resource-group "$az_resource_group_name" \
      --issuer "$issuer" \
      --subject "$subject" \
      --output json
}

create_az_role_assignment_sp() {
  local az_role_assignment_name="$1"
  local az_role_assignment_subscription_id="$2"
  local az_role_assignment_object_id="$3"
  local az_role_assignment_scope="$4"

  az role assignment create \
    --role "$az_role_assignment_name" \
    --subscription "$az_role_assignment_subscription_id" \
    --assignee-object-id  "$az_role_assignment_object_id" \
    --assignee-principal-type ServicePrincipal \
    --scope "$az_role_assignment_scope" \
    --output json
}

delete_az_ad_app() {
  local az_ad_app_id="$1"

  az ad app delete \
    --id "$az_ad_app_id" \
    --output json
}


delete_az_group() {
  local az_resource_group_name="$1"

  az group delete \
    --name "$az_resource_group_name" \
    --yes \
    --no-wait \
    --output json
}

get_az_ad_app_by_name() {
  local az_ad_app_display_name="$1"

  az ad app list \
    --display-name "$az_ad_app_display_name" \
    --output json
}

get_az_ad_app_fed_cred_id() {
  local az_ad_app_id="$1"
  local subj="$2"

  az ad app federated-credential list \
    --id "$az_ad_app_id" \
    --query "[?subject=='$subj']" \
    --output json
}

get_az_ad_sp_id() {
  local az_ad_app_id="$1"
  local filter=""
  local params=""

  filter="appId eq '${az_ad_app_id}'"
  params=("ad" "sp" "list" "--filter" "$filter" "--output" "json")
  az "${params[@]}"
}

get_az_identity_by_name() {
  local az_identity_name="$1"
  local az_resource_group_name="$2"
  local query=""

  query="[?name == '$az_identity_name']"

  az identity list \
    --resource-group "$az_resource_group_name" \
    --query "$query" \
    --output json
}

get_az_identity_fed_cred() {
  local az_identity_name="$1"
  local az_resource_group_name="$2"
  local subj="$3"

  az identity federated-credential list \
    --identity-name "$az_identity_name" \
    --resource-group "$az_resource_group_name" \
    --query "[?subject=='$subj']" \
    --output json
}

get_az_subscription_id() {
  local az_account=""
  az_account=$(az account show \
                 --output json)
  jq -r '.id' <<< "$az_account"
}

get_az_subscription_name() {
  local az_account=""
  az_account=$(az account show \
                 --output json)
  jq -r '.name' <<< "$az_account"
}

get_az_tenant_id() {
  local az_account=""
  az_account=$(az account show \
                 --output json)
  jq -r '.tenantId' <<< "$az_account"
}
