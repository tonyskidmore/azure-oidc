#!/bin/bash

banner_message() {
    local message="$1"
    echo "===================================================================================================="
    echo "$message"
    echo "===================================================================================================="
}

check_ado_oidc_issuer_url() {
  local issuer_url="$1"
  local regex="^https:\/\/vstoken\.dev\.azure\.com\/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"

  if [[ ! $issuer_url =~ $regex ]]; then
      echo "$issuer_url: invalid Azure DevOps OIDC issuer URL"
      return 1
  fi
}

check_github_oidc_issuer_url() {
  local issuer_url="$1"
  
  if [[ "$issuer_url" != "https://token.actions.githubusercontent.com" ]]; then
      echo "$issuer_url: invalid GitHub OIDC issuer URL"
      return 1
  fi
}

check_oidc_issuer_url() {
  local issuer_url="$1"
  local fed_cred_scenario="$2"

  case "$fed_cred_scenario" in
    "GitHub" ) check_github_oidc_issuer_url "$issuer_url";
      ;;
    "AzureDevOps" ) check_ado_oidc_issuer_url "$issuer_url";
      ;;
    * ) echo "Invalid AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO: $AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO";
      return 1
      ;;
  esac

}

check_github_oidc_subject_format() {
  # TODO: does not fully validate semantic versioning
  local input="$1"
  local regex="^repo:[a-zA-Z0-9_\-]+\/[a-zA-Z0-9_\-]+(:[a-zA-Z0-9_\-\/\.]+)+$"

  if [[ ! $input =~ $regex ]]; then
      echo "$input: invalid GitHub OIDC subject format"
      return 1
  fi
}

check_ado_oidc_subject_format() {
  local input="$1"
  local regex="^sc:\/\/[a-zA-Z0-9_\-]+\/[a-zA-Z0-9_\-]+\/[a-zA-Z0-9_\-]+$"

  if [[ ! $input =~ $regex ]]; then
      echo "$input: invalid Azure DevOps OIDC subject format"
      return 1
  fi
}

check_oidc_subject_format() {
  local subject="$1"
  local fed_cred_scenario="$2"

  case "$fed_cred_scenario" in
    "GitHub" ) check_github_oidc_subject_format "$subject";
      ;;
    "AzureDevOps" ) check_ado_oidc_subject_format "$subject";
      ;;
    * ) echo "Invalid AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO: $AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO";
      return 1
      ;;
  esac
}


debug_output() {
  local lineno="$1"
  local message="$2"
  local value="$3"
  # local file_only="${4:-false}"
  local calling_lineno=""
  local debug_line=""
  local utc_timestamp=""

  if [[ "$DEBUG" == "true" || -n "$DEBUG_FILE" ]]
  then
    calling_lineno=$((lineno - 1))
    utc_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    printf -v debug_line "%s DEBUG: line %s of %s: %s:\n%s\n" "$utc_timestamp" "$calling_lineno" "${FUNCNAME[1]}" "$message" "$value"
    [[ -n "$DEBUG_FILE" ]] && echo "$debug_line" >> "$DEBUG_FILE"
    # [[ "$file_only" != "true" ]] && echo "$debug_line"
    echo "$debug_line" >&2
  fi
}

exit_script() {
  local message="$1"
  local exit_code="${2:-1}"
  echo "$message"
  exit "$exit_code"
}

extract_ado_organization_name() {
  local url="$1"
  local org_name

  # Remove protocol (http:// or https://)
  url="${url#http://}"
  url="${url#https://}"

  # Handle legacy format like '{organization}.visualstudio.com'
  if [[ $url == *".visualstudio.com"* ]]; then
      org_name="${url%%.*}"
  else
      # Handle standard format like 'dev.azure.com/{organization}'
      url="${url#*dev.azure.com/}"
      org_name="${url%%/*}"
  fi

  # Remove trailing slashes if any
  org_name="${org_name%%/*}"

  # Remove any query parameters or anchors
  org_name="${org_name%%\?*}"
  org_name="${org_name%%\#*}"

  echo "$org_name"
}

get_fed_cred_params() {
  local subj_name="$1"
  local issuer="$2"
  local subj="$3"

  echo "{\"name\": \"$subj_name\", \"issuer\": \"$issuer\", \"subject\": \"$subj\", \"description\": \"${AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO} to Azure OIDC\", \"audiences\": [\"api://AzureADTokenExchange\"]}"
}

replace_colon_and_slash() {
    local input=$1
    local output=${input//:/-}
    output=${output//\//-}
    echo "$output" | tr -s '-'
}

trim_spaces() {
  # remove leading and then trailing spaces
  local input="$1"
  local output="${input#"${input%%[![:space:]]*}"}"
  output="${output%"${output##*[![:space:]]}"}"
  echo "$output"
}

yes_no_question() {
  local question="$1"
  read -rp "$question [y/n] " answer

  case $answer in
      [Yy]* ) echo "yes";
              ;;
      [Nn]* ) echo "no";
              ;;
      * )     echo "";
              ;;
  esac
}
