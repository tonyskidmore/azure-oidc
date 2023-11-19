#!/bin/bash

set_variables() {
  AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-${oidc_subscription:-$(get_az_subscription_id)}}"
  AZURE_TENANT_ID="${AZURE_TENANT_ID:-$(get_az_tenant_id)}"
  AZURE_RESOURCE_GROUP_NAME="${AZURE_RESOURCE_GROUP_NAME:-$oidc_resource_group_name}"
  AZURE_RESOURCE_GROUP_LOCATION="${AZURE_RESOURCE_GROUP_LOCATION:-$oidc_resource_group_location}"
  AZURE_RESOURCE_GROUP_TAGS="${AZURE_RESOURCE_GROUP_TAGS:-$oidc_resource_group_tags}"
  AZURE_OIDC_APP_NAME="${AZURE_OIDC_APP_NAME:-$oidc_app_name}"
  AZURE_OIDC_ROLE_ASSIGNMENT="${AZURE_OIDC_ROLE_ASSIGNMENT:-$oidc_role_assignment}"
  AZURE_OIDC_SUBJECT_IDENTIFIER="${AZURE_OIDC_SUBJECT_IDENTIFIER:-$oidc_subject_identifier}"
  AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO="${AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO:-$oidc_federated_credential_scenario}"
  AZURE_OIDC_MODE="${AZURE_OIDC_MODE:-$mode}"
  AZURE_OIDC_QUIET="${AZURE_OIDC_QUIET:-$quiet}"
  AZURE_OIDC_YES_FLAG="${AZURE_OIDC_YES_FLAG:-$yes}"
  AZURE_OIDC_JSON_OUTPUT="${AZURE_OIDC_JSON_OUTPUT:-$json_file_location}"

  [[ -z "$AZURE_RESOURCE_GROUP_LOCATION" ]] && AZURE_RESOURCE_GROUP_LOCATION="uksouth"

  if [[ "$AZURE_OIDC_QUIET" != "true" ]]
  then
    banner_message "configuration variables"

    # shellcheck disable=SC2154
    printf "AZURE_OIDC_MODE: %s\n" "$AZURE_OIDC_MODE"
    printf "AZURE_OIDC_QUIET: %s\n" "$AZURE_OIDC_QUIET"
    printf "AZURE_OIDC_YES_FLAG: %s\n" "$AZURE_OIDC_YES_FLAG"
    printf "AZURE_SUBSCRIPTION_ID: %s\n" "$AZURE_SUBSCRIPTION_ID"
    printf "AZURE_TENANT_ID: %s\n" "$AZURE_TENANT_ID"
    printf "AZURE_RESOURCE_GROUP_NAME: %s\n" "$AZURE_RESOURCE_GROUP_NAME"
    printf "AZURE_RESOURCE_GROUP_LOCATION: %s\n" "$AZURE_RESOURCE_GROUP_LOCATION"
    printf "AZURE_RESOURCE_GROUP_TAGS: %s\n" "$AZURE_RESOURCE_GROUP_TAGS"
    printf "AZURE_OIDC_APP_NAME: %s\n" "$AZURE_OIDC_APP_NAME"
    printf "AZURE_OIDC_ROLE_ASSIGNMENT: %s\n" "$AZURE_OIDC_ROLE_ASSIGNMENT"
    printf "AZURE_OIDC_JSON_OUTPUT: %s\n" "$AZURE_OIDC_JSON_OUTPUT"
    printf "AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO: %s\n" "$AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO"
    printf "AZURE_OIDC_SUBJECT_IDENTIFIER: %s\n\n" "$AZURE_OIDC_SUBJECT_IDENTIFIER"
  fi

  if [[ -n "$AZURE_OIDC_JSON_OUTPUT" ]]
  then
    # shellcheck disable=SC2034
    assoc_array["oidc_app_name"]="$AZURE_OIDC_APP_NAME"
    assoc_array["resource_group_name"]="$AZURE_RESOURCE_GROUP_NAME"
    assoc_array["azure_subscription_id"]="$AZURE_SUBSCRIPTION_ID"
    assoc_array["azure_tenant_id"]="$AZURE_TENANT_ID"
  fi
}

create_oidc_app() {

  set_variables

  [[ "$AZURE_OIDC_QUIET" != "true" ]] && banner_message "Configuring Azure for GitHub OIDC"

  app_id=$(create_az_ad_app "$AZURE_OIDC_APP_NAME")
  [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "OIDC app_id: %s\n" "$app_id"
  # shellcheck disable=SC2034
  [[ -n "$AZURE_OIDC_JSON_OUTPUT" ]] && assoc_array["app_id"]="$app_id"

  sp_id=$(get_az_ad_sp_id "$app_id")
  [[ -z "$sp_id" ]] && sp_id=$(create_az_ad_sp "$app_id")
  # shellcheck disable=SC2034
  [[ -n "$AZURE_OIDC_JSON_OUTPUT" ]] && assoc_array["sp_id"]="$sp_id"

  [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "OIDC sp_id: %s\n" "$sp_id"

  scope="/subscriptions/${AZURE_SUBSCRIPTION_ID}"
  if [[ -n "$AZURE_RESOURCE_GROUP_NAME" ]]
  then
    [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "Creating resource group if it does not exist: %s\n" "$AZURE_RESOURCE_GROUP_NAME"
    create_az_group "$AZURE_RESOURCE_GROUP_NAME" "$AZURE_RESOURCE_GROUP_LOCATION" "$AZURE_RESOURCE_GROUP_TAGS">/dev/null
    scope="$scope/resourceGroups/${AZURE_RESOURCE_GROUP_NAME}"
    [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "scope: %s\n" "$scope"
  fi

  while IFS=, read -ra roles; do
    for role in "${roles[@]}"; do
      [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "Setting %s RBAC role assignment to the scope of %s\n" "$role" "$scope"

      role_assignment=$(trim_spaces "$role")

      create_az_role_assignment_sp "$role_assignment" \
                                    "$AZURE_SUBSCRIPTION_ID" \
                                    "$sp_id" "$scope" >/dev/null
    done
  done <<< "$AZURE_OIDC_ROLE_ASSIGNMENT"
  [[ -z "$AZURE_OIDC_ROLE_ASSIGNMENT" ]]  && echo "INFORMATION: no RBAC assignments specified, you will need to configure any RBAC requirements in Azure"

  while IFS=, read -ra subjects; do
    for subject in "${subjects[@]}"; do
      fc_subject=$(trim_spaces "$subject")
      [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "Checking federated credential: %s\n" "$fc_subject"
      check_github_oidc_subject_format "$fc_subject"
      subject_name=$(replace_colon_and_slash "$fc_subject")

      params=$(get_fed_cred_params "$fc_subject" "$subject_name")
      fed_cred_id=$(get_az_ad_app_fed_cred_id "$app_id" "$fc_subject") >/dev/null


      if [[ -z "$fed_cred_id" ]]
      then
        [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "Creating federated credential: %s\n" "$fc_subject"
        IFS=, read -r fed_cred_id fed_cred_subject <<< "$(create_az_ad_app_fed_cred "$app_id" "$params")"
      fi
      # shellcheck disable=SC2034
      [[ -n "$AZURE_OIDC_JSON_OUTPUT" ]] && assoc_array["fed_cred_id"]="$fed_cred_id"
      # shellcheck disable=SC2034
      [[ -n "$AZURE_OIDC_JSON_OUTPUT" && -n "$fed_cred_subject" ]] && assoc_array["fed_cred_subject"]="$fed_cred_subject"
    done
  done <<< "$AZURE_OIDC_SUBJECT_IDENTIFIER"
  [[ -z "$AZURE_OIDC_SUBJECT_IDENTIFIER" && "$AZURE_OIDC_QUIET" != "true" ]]  && echo "WARNING: no OIDC subjects have been specified, you will need to manually configure these in Azure"
  [[ -n "$AZURE_OIDC_JSON_OUTPUT" ]] && associative_array_to_json "assoc_array" | tee "$AZURE_OIDC_JSON_OUTPUT"
}

delete_oidc_app() {

  local az_ad_app_id=""
  local delete_app=""
  local delete_rg=""
  set_variables

  banner_message "Deleting Azure GitHub OIDC configuration"

  az_ad_app_id=$(get_az_ad_app_by_name "$AZURE_OIDC_APP_NAME")

  if [[ -n "$az_ad_app_id" ]]
  then
    printf "Deleting OIDC app %s with ID %s\n" "$AZURE_OIDC_APP_NAME" "$az_ad_app_id"
    [[ "$AZURE_OIDC_YES_FLAG" != "true" ]] && delete_app=$(yes_no_question "Would you like to delete this app?")
    [[ "$delete_app" == "yes" || "$AZURE_OIDC_YES_FLAG" == "true" ]] && delete_az_ad_app "$az_ad_app_id"
  fi

  if [[ -n "$AZURE_RESOURCE_GROUP_NAME" ]]
  then
    [[ "$AZURE_OIDC_YES_FLAG" != "true" ]] && delete_rg=$(yes_no_question "Would you like to delete the $AZURE_RESOURCE_GROUP_NAME resource group?  WARNING: all resources will be deleted")
    printf "Deleting resource group: %s\n" "$AZURE_RESOURCE_GROUP_NAME"
    [[ "$delete_rg" == "yes" || "$AZURE_OIDC_YES_FLAG" == "true"  ]] && delete_az_group "$AZURE_RESOURCE_GROUP_NAME"
  fi

}
