#!/bin/bash

build_params() {

  local method="$1"
  local url="$2"
  local data="$3"

  params=(
          "--silent" \
          "--show-error" \
          "--retry" "${HTTP_RETRIES:-10}" \
          "--retry-delay" "${HTTP_RETRY_DELAY:-3}" \
          "--retry-max-time" "${HTTP_RETRIES_MAX_TIME:-120}" \
          "--max-time" "${HTTP_MAX_TIME:-120}" \
          "--connect-timeout" "${HTTP_CONNECT_TIMEOUT:-20}" \
          "--write-out" "\n%{http_code}" \
          "--header" "Content-Type: application/json" \
          "--request" "$method"
  )

  if [[ "$method" == "POST" || "$method" == "PATCH" ]]
  then
    params+=("--data" "$data")
  fi

  params+=("--user" ":$AZURE_DEVOPS_EXT_PAT" "$url")
  debug_output "$LINENO" "params" "${params[*]}"

}

checkout() {
  local method="$1"

  debug_output "$LINENO" "exit_code" "$exit_code"
  debug_output "$LINENO" "http_code" "$http_code"
  if [[ "$exit_code" != "0" ]]; then
    printf "%s\n" "$out"
    return "$exit_code"  # Return the exit code of the curl command
  else
    echo "$out"
    case "$http_code" in
      200)
        [[ "${method,,}" != "delete" ]] && return 0
        ;;
      204)
        [[ "${method,,}" == "delete" ]] && return 0
        ;;
      401)
        raise "401 Unauthorized, probable PAT permissions issue"
        debug_output "$LINENO" "http_code" "$http_code"
        return 7
        ;;
      *)
        handle_http_errors "$http_code" "$out"
        return $?
        ;;
    esac
  fi
}

handle_http_errors() {
  local http_code="$1"
  local response="$2"

  if [[ -n "$response" ]] && [[ "$(echo "$response" | jq empty > /dev/null 2>&1; echo $?)" = "0" ]]; then
    printf "Parsed JSON successfully and got something other than false/null\n"
    message="$(echo "$response" | jq -r '.message')"
    raise "Error: $message"
    return 2
  else
    printf "Failed to parse JSON, or got false/null\n"
    if echo "$response" | grep -q "_signin"; then
      raise "Azure DevOps PAT token is not correct"
      return 4
    elif echo "$response" | grep -q "The resource cannot be found"; then
      raise "The resource cannot be found"
      return 5
    elif [[ "$http_code" == "401" ]]; then
      echo "mode: $mode"
      raise "401 Unauthorized, probable PAT permissions issue"
      debug_output "$LINENO" "http_code" "$http_code"
      return 7
    else
      raise "Unknown error"
      printf "%s\n" "$response"
      return 3
    fi
  fi
}

create_ado_service_endpoint() {
  local data="$1"
  local projectUrl=""

  projectUrl="${AZDO_ORG_SERVICE_URL}/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4"
  rest_api_call "POST" "$projectUrl" "$data"
}

get_ado_account_by_user_id() {
  local user_id="$1"
  local account=""
  local url=""

  url="https://app.vssps.visualstudio.com/_apis/accounts?memberId=${user_id}&api-version=6.0"
  account=$(rest_api_call "GET" "$url")

  echo "$account"
}


get_ado_current_user_id () {
  local user_id=""
  local url=""
  local profile_data=""

  url="https://app.vssps.visualstudio.com/_apis/profile/profiles/me?api-version=6.0"
  profile_data=$(rest_api_call "GET" "$url")
  debug_output "$LINENO" "profile_data" "$profile_data"

  user_id=$(jq -r '.id' <<< "$profile_data")

  echo "$user_id"
}

get_ado_organization_id() {
  local ado_organization_name="$1"
  local user_id=""
  local account=""
  local organization_id=""

  # user_id will only be returned if AZURE_DEVOPS_EXT_PAT is defined for "All accessible organizations"
  # if user_id is empty, then we cannot dynamically get the organization id
  user_id=$(get_ado_current_user_id)
  if [[ -n "$user_id" ]]
  then
    account=$(get_ado_account_by_user_id "$user_id")
    debug_output "$LINENO" "account" "$account"
    organization_id=$(jq_ado_get_org_id "$ado_organization_name" "$account")
    debug_output "$LINENO" "organization_id" "$organization_id"
  fi

  echo "$organization_id"

}

get_ado_projects() {
  local projectUrl=""

  projectUrl="${AZDO_ORG_SERVICE_URL}/_apis/projects?api-version=6.0"

  rest_api_call "GET" "$projectUrl"
}

get_ado_project_id_by_name() {
  local projectName="$1"
  local projects=""

  projects=$(get_ado_projects)
  jq -r --arg projectName "$projectName" '.value[] | select(.name == $projectName) | .id' <<< "$projects"
}

raise() {
  printf "%s\n" "$1" >&2
}

rest_api_call() {
  local method="$1"
  local url="$2"
  local data="$3"

  exit_code=0
  http_code=0

  if [[ "$method" == "GET" || "$method" == "DELETE" ]] && [[ "$#" -ne 2 ]]
  then
      printf "Expected 2 function arguments, got %s\n" "$#"
      return 1
  elif [[ "$method" == "POST" || "$method" == "PATCH" ]] && [[ "$#" -ne 3 ]]
  then
      printf "Expected 3 function arguments, got %s\n" "$#"
      return 1
  fi

  if [[ "$method" != "GET" && "$method" != "POST" && "$method" != "PATCH" && "$method" != "DELETE" ]]
  then
    printf "Expected method to be one of: GET,POST,PATCH.DELETE got %s\n" "$method"
    return 1
  fi

  if [[ ! $url =~ ^https:\/\/.+\/_apis.+$ ]]
  then
    printf "Invalid or missing URL: %s\n" "$url"
    return 1
  fi

  build_params "$method" "$url" "$data"

  res=$(curl "${params[@]}")
  exit_code=$?
  debug_output "$LINENO" "exit_code" "$exit_code"

  # https://unix.stackexchange.com/questions/572424/retrieve-both-http-status-code-and-content-from-curl-in-a-shell-script
  http_code=$(tail -n1 <<< "$res") # get the last line
  debug_output "$LINENO" "http_code" "$http_code"
  out=$(sed '$ d' <<< "$res") # get all but the last line which contains the status code
  debug_output "$LINENO" "out" "$out"

  # function to validate the response
  checkout "$method"

}


