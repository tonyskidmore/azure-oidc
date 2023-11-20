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
  AZURE_OIDC_DEBUG="${AZURE_OIDC_DEBUG:-$debug}"
  AZURE_OIDC_QUIET="${AZURE_OIDC_QUIET:-$quiet}"
  AZURE_OIDC_YES_FLAG="${AZURE_OIDC_YES_FLAG:-$yes}"
  AZURE_OIDC_JSON_OUTPUT="${AZURE_OIDC_JSON_OUTPUT:-$json_file_location}"

  [[ -z "$AZURE_RESOURCE_GROUP_LOCATION" ]] && AZURE_RESOURCE_GROUP_LOCATION="uksouth"

  if [[ "$AZURE_OIDC_QUIET" != "true" ]]
  then
    banner_message "configuration variables"

    # shellcheck disable=SC2154
    printf "AZURE_OIDC_MODE: %s\n" "$AZURE_OIDC_MODE"
    printf "AZURE_OIDC_DEBUG: %s\n" "$AZURE_OIDC_DEBUG"
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
  local json=""
  local count=""
  local az_ad_app_id=""
  local sp_id=""
  local sub_scope=""
  local rg_scope=""
  local full_scope=""

  set_variables

  [[ "$AZURE_OIDC_QUIET" != "true" ]] && banner_message "Configuring Azure for GitHub OIDC"

  json=$(get_az_ad_app_by_name "$AZURE_OIDC_APP_NAME")
  debug_output "$LINENO" "get_az_ad_app_by_name JSON" "$json"
  jq_check_json "$json" || exit_script "create_oidc_app: invalid JSON from get_az_ad_app_by_name $AZURE_OIDC_APP_NAME"  1
  count=$(jq_count_list "$json")
  debug_output "$LINENO" "count" "$count"

  if [[ "$count" == "1" ]]
  then
    az_ad_app_id=$(jq_get_first_by_key_ref "$json" "appId")
    debug_output "$LINENO" "az_ad_app_id" "$az_ad_app_id"
  else
    json=$(create_az_ad_app "$AZURE_OIDC_APP_NAME")
    debug_output "$LINENO" "create_az_ad_app JSON" "$json"
    jq_check_json "$json" || exit_script "create_az_ad_app: invalid JSON from create_az_ad_app $AZURE_OIDC_APP_NAME"  1
    az_ad_app_id=$(jq_get_by_key_ref "$json" "appId")
    debug_output "$LINENO" "az_ad_app_id" "$az_ad_app_id"
  fi

  [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "OIDC app_id: %s\n" "$az_ad_app_id"

  # shellcheck disable=SC2034
  [[ -n "$AZURE_OIDC_JSON_OUTPUT" ]] && assoc_array["app_id"]="$az_ad_app_id"

  json=$(get_az_ad_sp_id "$az_ad_app_id")
  debug_output "$LINENO" "get_az_ad_sp_id JSON" "$json"

  jq_check_json "$json" || exit_script "create_oidc_app: invalid JSON from get_az_ad_sp_id $az_ad_app_id"  1
  count=$(jq_count_list "$json")
  debug_output "$LINENO" "count" "$count"

  if [[ "$count" == "1" ]]
  then
    sp_id=$(jq_get_first_by_key_ref "$json" "id")
    debug_output "$LINENO" "sp_id" "$sp_id"
  fi


  if [[ -z "$sp_id" ]]
  then
    json=$(create_az_ad_sp "$az_ad_app_id")
    debug_output "$LINENO" "create_az_ad_sp JSON" "$json"
    sp_id=$(jq_get_by_key_ref "$json" "id")
    debug_output "$LINENO" "sp_id" "$sp_id"
  fi
  # shellcheck disable=SC2034
  [[ -n "$AZURE_OIDC_JSON_OUTPUT" ]] && assoc_array["sp_id"]="$sp_id"

  [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "OIDC sp_id: %s\n" "$sp_id"

  sub_scope="/subscriptions/${AZURE_SUBSCRIPTION_ID}"
  debug_output "$LINENO" "sub_scope" "$sub_scope"

  if [[ -n "$AZURE_RESOURCE_GROUP_NAME" ]]
  then
    [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "Creating resource group if it does not exist: %s\n" "$AZURE_RESOURCE_GROUP_NAME"
    json=$(create_az_group "$AZURE_RESOURCE_GROUP_NAME" "$AZURE_RESOURCE_GROUP_LOCATION" "$AZURE_RESOURCE_GROUP_TAGS")
    debug_output "$LINENO" "create_az_group JSON" "$json"
    rg_scope="/resourceGroups/${AZURE_RESOURCE_GROUP_NAME}"
    debug_output "$LINENO" "rg_scope" "$rg_scope"
  fi

  full_scope="${sub_scope}${rg_scope}"
  debug_output "$LINENO" "full_scope" "$full_scope"

  while IFS=, read -ra roles; do
    for role in "${roles[@]}"; do
      [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "Setting %s RBAC role assignment to the scope of %s\n" "$role" "$full_scope"

      role_assignment=$(trim_spaces "$role")
      debug_output "$LINENO" "role_assignment" "$role_assignment"

      json=$(create_az_role_assignment_sp "$role_assignment" "$AZURE_SUBSCRIPTION_ID" "$sp_id" "$full_scope")
      debug_output "$LINENO" "create_az_role_assignment_sp JSON" "$json"
    done
  done <<< "$AZURE_OIDC_ROLE_ASSIGNMENT"
  [[ -z "$AZURE_OIDC_ROLE_ASSIGNMENT" ]]  && echo "INFORMATION: no RBAC assignments specified, you will need to configure any RBAC requirements in Azure"

  while IFS=, read -ra subjects; do
    for subject in "${subjects[@]}"; do
      fc_subject=$(trim_spaces "$subject")
      debug_output "$LINENO" "fc_subject" "$fc_subject"
      [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "Checking federated credential: %s\n" "$fc_subject"
      check_github_oidc_subject_format "$fc_subject"
      subject_name=$(replace_colon_and_slash "$fc_subject")
      debug_output "$LINENO" "subject_name" "$fc_subject"

      params=$(get_fed_cred_params "$fc_subject" "$subject_name")
      debug_output "$LINENO" "params" "$params"
      json=$(get_az_ad_app_fed_cred_id "$az_ad_app_id" "$fc_subject")
      debug_output "$LINENO" "get_az_ad_app_fed_cred_id JSON" "$json"

      fed_cred_id=$(jq_get_first_by_key_ref "$json" "id")
      debug_output "$LINENO" "fed_cred_id" "$fed_cred_id"
      fed_cred_subject=$(jq_get_first_by_key_ref "$json" "subject")
      debug_output "$LINENO" "fed_cred_subject" "$fed_cred_subject"

      if [[ -z "$fed_cred_id" ]]
      then
        [[ "$AZURE_OIDC_QUIET" != "true" ]] && printf "Creating federated credential: %s\n" "$fc_subject"
        json=$(create_az_ad_app_fed_cred "$az_ad_app_id" "$params")
        debug_output "$LINENO" "create_az_ad_app_fed_cred JSON" "$json"
        fed_cred_id=$(jq_get_by_key_ref "$json" "id")
        debug_output "$LINENO" "fed_cred_id" "$fed_cred_id"
        fed_cred_subject=$(jq_get_by_key_ref "$json" "subject")
        debug_output "$LINENO" "fed_cred_subject" "$fed_cred_subject"
      fi
      # shellcheck disable=SC2034
      [[ -n "$AZURE_OIDC_JSON_OUTPUT" ]] && assoc_array["fed_cred_id"]="$fed_cred_id"
      # shellcheck disable=SC2034
      [[ -n "$AZURE_OIDC_JSON_OUTPUT" && -n "$fed_cred_subject" ]] && assoc_array["fed_cred_subject"]="$fed_cred_subject"
    done
  done <<< "$AZURE_OIDC_SUBJECT_IDENTIFIER"
  [[ -z "$AZURE_OIDC_SUBJECT_IDENTIFIER" && "$AZURE_OIDC_QUIET" != "true" ]]  && echo "WARNING: no OIDC subjects have been specified, you will need to manually configure these in Azure"
  [[ -n "$AZURE_OIDC_JSON_OUTPUT" ]] && jq_associative_array_to_json "assoc_array" | tee "$AZURE_OIDC_JSON_OUTPUT"
}

delete_oidc_app() {

  local az_ad_app_id=""
  local delete_app=""
  local delete_rg=""
  local json=""
  local count=""
  set_variables

  banner_message "Deleting Azure GitHub OIDC configuration"

  json=$(get_az_ad_app_by_name "$AZURE_OIDC_APP_NAME")
  debug_output "$LINENO" "get_az_ad_app_by_name JSON" "$json"
  jq_check_json "$json" || exit_script "delete_oidc_app: invalid JSON from get_az_ad_app_by_name $AZURE_OIDC_APP_NAME"  1
  count=$(jq_count_list "$json")

  if [[ "$count" == "1" ]]
  then
    az_ad_app_id=$(jq_get_first_by_key_ref "$json" "appId")
    printf "Deleting OIDC app %s with ID %s\n" "$AZURE_OIDC_APP_NAME" "$az_ad_app_id"
    [[ "$AZURE_OIDC_YES_FLAG" != "true" ]] && delete_app=$(yes_no_question "Would you like to delete this app?")
    if [[ "$delete_app" == "yes" || "$AZURE_OIDC_YES_FLAG" == "true" ]]
    then
      json=$(delete_az_ad_app "$az_ad_app_id")
      debug_output "$LINENO" "delete_az_group JSON" "$json"
    fi
  fi

  if [[ -n "$AZURE_RESOURCE_GROUP_NAME" ]]
  then
    [[ "$AZURE_OIDC_YES_FLAG" != "true" ]] && delete_rg=$(yes_no_question "Would you like to delete the $AZURE_RESOURCE_GROUP_NAME resource group?  WARNING: all resources will be deleted")
    if [[ "$delete_rg" == "yes" || "$AZURE_OIDC_YES_FLAG" == "true"  ]]
    then
      printf "Deleting resource group: %s\n" "$AZURE_RESOURCE_GROUP_NAME"
      json=$(delete_az_group "$AZURE_RESOURCE_GROUP_NAME")
      debug_output "$LINENO" "delete_az_group JSON" "$json"
    fi
  fi

}

debug_output() {
  local lineno="$1"
  local message="$2"
  local value="$3"
  local calling_lineno=""

  if [[ "$AZURE_OIDC_DEBUG" == "true" ]]
  then
    calling_lineno=$((lineno - 1))
    printf "DEBUG: line %s of %s: %s: \n%s\n" "$calling_lineno" "${FUNCNAME[1]}" "$message" "$value"
  fi
}
