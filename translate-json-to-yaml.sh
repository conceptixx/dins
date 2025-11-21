#!/bin/bash

# File paths
DEPS_YAML="service-dependency.yml"
TMP_JSON="merged-deps-tmp.json"

function usage() {
  echo "Usage:"
  echo "  $0 --M|--merge <json-file>"
  echo "  $0 --A|--add <json-file>"
  echo "  $0 --R|--remove <json-file>"
  echo "  $0 --C|--clean <service1> [<service2> ...]"
  exit 1
}

function ensure_yq() {
  if ! command -v yq >/dev/null 2>&1; then
    echo "[ERROR] 'yq' is required. Install it with 'brew install yq'"
    exit 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "[ERROR] 'jq' is required. Install it with 'brew install jq'"
    exit 1
  fi
}

function merge_json() {
  jq -s 'reduce .[] as $item ({}; . * $item)' "$@" > "$TMP_JSON"
  yq -P eval "$TMP_JSON" > "$DEPS_YAML"
  rm -f "$TMP_JSON"
  echo "[INFO] Merged into $DEPS_YAML"
}

function add_json() {
  if [ ! -f "$DEPS_YAML" ]; then
    cp "$1" "$TMP_JSON"
  else
    yq -o=json eval "$DEPS_YAML" > "$TMP_JSON"
    jq -s '.[0] * .[1]' "$TMP_JSON" "$1" > tmp-combined.json
    mv tmp-combined.json "$TMP_JSON"
  fi
  yq -P eval "$TMP_JSON" > "$DEPS_YAML"
  rm -f "$TMP_JSON"
  echo "[INFO] Added entries from $1 to $DEPS_YAML"
}

function remove_json() {
  yq -o=json eval "$DEPS_YAML" > "$TMP_JSON"
  for dep in $(jq -r 'keys[]' "$1"); do
    jq "del(.$dep)" "$TMP_JSON" > tmp && mv tmp "$TMP_JSON"
  done
  yq -P eval "$TMP_JSON" > "$DEPS_YAML"
  rm -f "$TMP_JSON"
  echo "[INFO] Removed entries from $1"
}

function clean_services() {
  yq -o=json eval "$DEPS_YAML" > "$TMP_JSON"
  for service in "$@"; do
    jq "to_entries | map(.value |= map(select(. != \"$service\"))) | from_entries" "$TMP_JSON" > tmp && mv tmp "$TMP_JSON"
  done
  # Also clean up empty lists
  jq 'with_entries(select(.value | length > 0))' "$TMP_JSON" > tmp && mv tmp "$TMP_JSON"
  yq -P eval "$TMP_JSON" > "$DEPS_YAML"
  rm -f "$TMP_JSON"
  echo "[INFO] Cleaned services: $*"
}

# Entry point
ensure_yq

case "$1" in
  --M|--merge)
    shift
    merge_json "$@"
    ;;
  --A|--add)
    shift
    add_json "$1"
    ;;
  --R|--remove)
    shift
    remove_json "$1"
    ;;
  --C|--clean)
    shift
    clean_services "$@"
    ;;
  *)
    usage
    ;;
esac
