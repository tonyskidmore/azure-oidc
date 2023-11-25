#!/bin/bash

banner_message() {
    local message="$1"
    echo "===================================================================================================="
    echo "$message"
    echo "===================================================================================================="
}

check_github_oidc_subject_format() {
  # TODO: does not fully validate semantic versioning
  local input="$1"
  local regex="^repo:[a-zA-Z0-9_\-]+\/[a-zA-Z0-9_\-]+(:[a-zA-Z0-9_\-\/\.]+)+$"

  if [[ ! $input =~ $regex ]]; then
      echo "$input: invalid GitHub OIDC subject format"
      exit 1
  fi
}

check_ado_oidc_subject_format() {
  local input="$1"
  local regex="^sc:\/\/[a-zA-Z0-9_\-]+\/[a-zA-Z0-9_\-]+\/[a-zA-Z0-9_\-]+$"

  if [[ ! $input =~ $regex ]]; then
      echo "$input: invalid Azure DevOps OIDC subject format"
      exit 1
  fi
}

check_oidc_subject_format() {
  local subject="$1"

  case "$AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO" in
      "GitHub" ) check_github_oidc_subject_format "$subject";
              ;;
      "AzureDevOps" ) check_ado_oidc_subject_format "$subject";
              ;;
      * )     echo "Invalid AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO: $AZURE_OIDC_FEDERATED_CREDENTIAL_SCENARIO";
              exit 1
              ;;
  esac
}

debug_output() {
  local lineno="$1"
  local message="$2"
  local value="$3"
  local calling_lineno=""

  if [[ "$DEBUG" == "true" ]]
  then
    calling_lineno=$((lineno - 1))
    printf "DEBUG: line %s of %s: %s: \n%s\n" "$calling_lineno" "${FUNCNAME[1]}" "$message" "$value"
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
