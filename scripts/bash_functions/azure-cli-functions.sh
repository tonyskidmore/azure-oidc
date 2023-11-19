#!/bin/bash

# create_az_ad_app() {
#   local az_ad_app_display_name="$1"
#   local az_ad_app_id=""
#   az_ad_app_id=$(az ad app create \
#                    --display-name "$az_ad_app_display_name" \
#                    --query appId \
#                    --output tsv)
#   echo "$az_ad_app_id"
# }

create_az_ad_app() {
  local az_ad_app_display_name="$1"

  az ad app create \
    --display-name "$az_ad_app_display_name" \
    --output json
}

create_az_ad_app_fed_cred() {
  local az_ad_app_id="$1"
  local fed_cred_params="$2"
  local fed_cred_output=""
  local fed_cred_id=""
  local fed_cred_subject=""

  fed_cred_output=$(az ad app federated-credential create \
      --id "$az_ad_app_id" \
      --query "{id: id, subject: subject}" \
      --parameters "$fed_cred_params")

  fed_cred_id=$(echo "$fed_cred_output" | jq -r '.id')
  fed_cred_subject=$(echo "$fed_cred_output" | jq -r '.subject')

  echo "$fed_cred_id,$fed_cred_subject"
}

create_az_ad_sp() {
  local az_ad_app_id="$1"
  local az_ad_sp_id=""
  az_ad_sp_id=$(az ad sp create \
                  --id "$az_ad_app_id" \
                  --query id \
                  --output tsv)
  echo "$az_ad_sp_id"
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
    --tags "${az_resource_group_tags_array[@]}"
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
    --scope "$az_role_assignment_scope"
}

delete_az_ad_app() {
  local az_ad_app_id="$1"
  az ad app delete --id "$az_ad_app_id"
}


delete_az_group() {
  local az_resource_group_name="$1"
  az group delete \
    --name "$az_resource_group_name" \
    --yes \
    --no-wait
}

# get_az_ad_app_by_name() {
#   local az_ad_app_display_name="$1"
#   local az_ad_app_id=""
#   az_ad_app_id=$(az ad app list \
#                    --display-name "$az_ad_app_display_name" \
#                    --query '[].appId' \
#                    --output t)
#   echo "$az_ad_app_id"
# }

get_az_ad_app_by_name() {
  local az_ad_app_display_name="$1"

  az ad app list \
    --display-name "$az_ad_app_display_name" \
    --output json
}

get_az_ad_app_fed_cred_id() {
  local az_ad_app_id="$1"
  local subj="$2"
  local az_ad_app_fed_cred_id=""
  az_ad_app_fed_cred_id=$(az ad app federated-credential list \
                              --id "$az_ad_app_id" \
                              --query "[?subject=='$subj'].id" \
                              --output tsv)
  echo "$az_ad_app_fed_cred_id"
}

get_az_ad_sp_id() {
  local az_ad_app_id="$1"
  local az_ad_sp_id=""
  local filter=""
  local params=""

  filter="appId eq '${az_ad_app_id}'"
  params=("ad" "sp" "list" "--filter" "$filter" "--output" "json")
  az "${params[@]}"
}

get_az_subscription_id() {
  local az_subscription_id=""
  az_subscription_id=$(az account show \
                         --query id \
                         --output tsv)
  echo "$az_subscription_id"
}

get_az_tenant_id() {
  local az_tenant_id=""
  az_tenant_id=$(az account show \
                   --query tenantId \
                   --output tsv)
  echo "$az_tenant_id"
}