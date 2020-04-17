
require_attr() {
  local type="$1"
  local name="$2"
  local val=$(jq -r ".$type.$name // \"\"" < "$payload")
  test -n "$val" || { echo "must supply '$name' $type attribute" >&2; exit 1; }
  echo "$val"
}
