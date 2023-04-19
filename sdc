#!/usr/bin/bash

set -euo pipefail
shopt -s extdebug
IFS=$'\n\t'

solisApiUrl="https://www.soliscloud.com:13333"

log() {
  if [[ $# -lt 2 ]]; then
    echo "Usage log <LEVEL> <MESSAGE>" >&2

    return 1
  fi

  level="${1:-}"
  shift

  if [[ ${level^^} == "DEBUG" && -z "${DEBUG:-}" ]]; then
    return 0
  else
    echo "${level^^}" "$@" >&2
  fi
}



calculateAuth() {
  local auth bodymd5 dt sign

  if [[ $# -ne 3 ]]; then
    log "ERROR" "calculateAuth requires date, message body (md5) and the api path as the only arguments."

    return 1
  fi

  dt="$1"
  bodymd5="$2"
  apiPath="$3"

  if [[ -z "$SC_KEYID" || -z "$SC_KEYSECRET" ]]; then
    log "Must supply Solis cloud api key id and secret (\$SC_KEYID and \$SC_KEYSECRET)"

    return 1
  fi

  log "DEBUG" "bodymd5=$bodymd5"
  sign="$(printf "POST\n%s\napplication/json\n%s\n%s" "$bodymd5" "$dt" "$apiPath" | openssl sha1 -hmac "$SC_KEYSECRET" -binary | openssl enc -base64)"
  log "DEBUG" "sign=$sign"
  auth="API $SC_KEYID:$sign"
  echo "$auth"
}

getDate() {
  date -u +"%a, %d %b %Y %T GMT"
}

getMD5() {
  echo -n "$body" | openssl dgst -md5 -binary | openssl enc -base64
}

makeRequest() {
  if [[ $# -lt 1 || $# -gt 2 ]]; then
    log "ERROR" "makeRequest needs the api path (\$1) and optionally a body (\$2)"
  fi
  apiPath="$1"
  body="${2:-}"
  : "${body:="{}"}"
  dt="$(getDate)"
  bodymd5=$(getMD5 "$body")
  auth="$(calculateAuth "$dt" "$bodymd5" "$apiPath")"

   cmd=(
     curl --request POST \
          --header "Content-MD5: $bodymd5"
          --header "Content-Type: application/json"
          --header "Date: $dt"
          --header "Authorization: $auth"
          --data "$body"
          "${solisApiUrl}${apiPath}"
   )

   log "DEBUG" $'cmd:\n'"${cmd[*]}"
   "${cmd[@]}"
}

main() {
  makeRequest "/v1/api/stationDetail" '{"id":"'"$SC_STATIONID"'"}'
}

# If sourced, load all functions.
# If executed, perform the actions as expected.
if [[ "$0" == "$BASH_SOURCE" ]] || [[ -z "$BASH_SOURCE" ]]; then
    main "$@"
fi
