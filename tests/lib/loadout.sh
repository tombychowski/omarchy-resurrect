#!/bin/bash

# Helpers for applied-loadout lifecycle cases. Each profile is intentionally
# tiny so a failure names the ownership transition under test.

write_package_loadout() {
  local dir="$1" name="$2"; shift 2
  mkdir -p "$dir"
  printf '%s\n' "$@" | jq -Rsc --arg name "$name" '
    {schemaVersion:1,kind:"omarchy-loadout",name:$name,author:"Test Author",
     description:"test loadout",createdAt:"2026-01-01T00:00:00Z",omarchy:"4.0.0",
     packages:{native:(split("\n")|map(select(length>0))),aur:[]},
     plugins:[],webapps:[],theme:{name:"",url:"",commit:""}}' >"$dir/profile.json"
}

registry_path() { printf '%s/ress/loadouts.json' "$XDG_STATE_HOME"; }

first_loadout_id() { jq -r '.loadouts[0].id' "$(registry_path)"; }

apply_yes() {
  ress apply --yes "$1"
}
