#!/bin/bash

associative_array_to_json() {
    local array_name=$1
    local -n array="$array_name"
    local json="{}"

    for key in "${!array[@]}"; do
        json=$(jq -n --arg key "$key" --arg value "${array[$key]}" --argjson json "$json" '$json | .[$key] = $value')
    done

    echo "$json"
}
