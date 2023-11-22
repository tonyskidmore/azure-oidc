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

exit_script() {
  local message="$1"
  local exit_code="${2:-1}"
  echo "$message"
  exit "$exit_code"
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
    echo "$output"
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
