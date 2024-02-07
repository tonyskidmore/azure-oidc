#!/bin/bash

jq_associative_array_to_json() {
    local array_name=$1
    local -n array="$array_name"
    local json="{}"

    for key in "${!array[@]}"; do
        json=$(jq -n --arg key "$key" --arg value "${array[$key]}" --argjson json "$json" '$json | .[$key] = $value')
    done

    echo "$json"
}

jq_check_json() {
    if echo "$1" | jq . > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

jq_count_list() {
  local json="$1"

  jq '. | length' <<< "$json"
}

function jq_ado_get_org_id {
    local ado_org_name="$1"
    local account_data="$2"
    local account_id=""
  
    account_id=$(jq --arg ado_org_name "$ado_org_name" -r '.value[] | select(.accountName == $ado_org_name) | .accountId' <<< "$account_data")
    echo "$account_id"
}


jq_get_by_key_ref() {
  local json="$1"
  local key="$2"

  jq -r --arg key "$key" '.[$key]' <<< "$json"
}

jq_get_first_by_key_ref() {
  local json="$1"
  local key="$2"

  jq -r --arg key "$key" '.[][$key]' <<< "$json"
}

jq_json_to_env_vars() {
  local json_string="$1"

  # loop through key/value using to_entries to add entries to variables
  while IFS="=" read -r key value; do
    export "$key"="$value"
  done < <(jq -r 'to_entries | .[] | .key + "=" + (.value|tostring)' <<< "${json_string}")
}
