#!/usr/bin/env bash
# EX-33, EX-33a: federation between a.example.test and b.example.test, which
# check deployed with tests/chainsaw-test.yaml.
# usage: federate.sh <ConfigMap of synapse-b> <the same without the option
# federation> <ConfigMap of synapse-a without ip_range_whitelist>
# PASSWORD_A and PASSWORD_B are the passwords of each server's admin.
set -euo pipefail
fail() { echo "$*" >&2; exit 1; }
b_on=$1 b_off=$2 a_open=$3
declare -A port=([a]=28008 [b]=28009) pf=()
tmp=$(mktemp -d)
trap 'kill "${pf[@]}" 2>/dev/null; rm -rf -- "$tmp"' EXIT
url() { echo "http://127.0.0.1:${port[$1]}"; }

# A port-forward ends with its pod, so serve starts it again after a restart.
serve() { # a|b
  [[ -z ${pf[$1]:-} ]] || kill "${pf[$1]}" 2>/dev/null || true
  kubectl -n "synapse-$1" port-forward service/matrix-synapse "${port[$1]}:8008" >/dev/null &
  pf[$1]=$!
  for _ in $(seq 30); do
    curl -fsS -o /dev/null "$(url "$1")/health" 2>/dev/null && return
    sleep 2
  done
  fail "no answer from $1.example.test through the port-forward"
}
# Applies a ConfigMap of synapse-<a|b> and replaces Synapse's pod, which
# reads its configuration only when it starts.
restart() { # a|b file
  local ns=synapse-$1 old new ready=''
  kubectl -n "$ns" apply --server-side --force-conflicts -f "$2" >/dev/null
  old=$(kubectl -n "$ns" get pod matrix-synapse-0 -o jsonpath='{.metadata.uid}')
  kubectl -n "$ns" delete pod matrix-synapse-0 --wait=true >/dev/null
  for _ in $(seq 60); do
    new=$(kubectl -n "$ns" get pod matrix-synapse-0 -o jsonpath='{.metadata.uid}' 2>/dev/null || true)
    [[ $new && $new != "$old" ]] &&
      kubectl -n "$ns" wait pod/matrix-synapse-0 --for=condition=Ready --timeout=10s >/dev/null 2>&1 && ready=1 && break
    sleep 5
  done
  [[ $ready ]] || fail "no ready pod replaced matrix-synapse-0 of $1.example.test"
  serve "$1"
}
login() { # a|b password
  jq -n --arg p "$2" '{type: "m.login.password", identifier: {type: "m.id.user", user: "admin"}, password: $p}' |
    curl -fsS -H 'Content-Type: application/json' --data @- "$(url "$1")/_matrix/client/v3/login" | jq -er .access_token
}
api() { # a|b token path [curl arguments]
  local s=$1 token=$2 path=$3
  shift 3
  curl -fsS -H "Authorization: Bearer $token" -H 'Content-Type: application/json' "$@" "$(url "$s")$path"
}
room() { # alias: a public room of b.example.test with that alias
  jq -n --arg a "$1" '{name: $a, room_alias_name: $a, preset: "public_chat"}' |
    api b "$tb" /_matrix/client/v3/createRoom --data @- | jq -er .room_id
}
send() { # a|b token room message
  jq -n --arg m "$4" '{msgtype: "m.text", body: $m}' |
    api "$1" "$2" "/_matrix/client/v3/rooms/$3/send/m.room.message/t$RANDOM$RANDOM" -X PUT --data @- >/dev/null
}
# The room's history as the server's client API returns it, waiting for a
# message that federation may still deliver.
reads() { # a|b token room message
  for _ in $(seq 30); do
    api "$1" "$2" "/_matrix/client/v3/rooms/$3/messages?dir=b&limit=50" |
      jq -e --arg m "$4" '[.chunk[] | select(.content.body == $m)] | length == 1' >/dev/null && return
    sleep 2
  done
  return 1
}
join() { # alias: the HTTP status of a.example.test's join, the answer in $tmp/join
  curl -sS -o "$tmp/join" -w '%{http_code}' -H "Authorization: Bearer $ta" -H 'Content-Type: application/json' \
    --data '{}' "$(url a)/_matrix/client/v3/join/%23$1%3Ab.example.test"
}
serve a
serve b
ta=$(login a "$PASSWORD_A") || fail "the admin of a.example.test cannot log in"
tb=$(login b "$PASSWORD_B") || fail "the admin of b.example.test cannot log in"

# EX-33: the admin of a.example.test joins a room of b.example.test by its
# alias, and both read each other's message.
id=$(room fed)
from_b="hello from b.example.test $RANDOM"
send b "$tb" "$id" "$from_b"
status=$(join fed)
answer=$(<"$tmp/join")
[[ $status == 200 ]] || fail "joining #fed:b.example.test from a.example.test got $status: $answer"
[[ $(jq -r .room_id <<<"$answer") == "$id" ]] || fail "a.example.test joined $answer, not $id"
reads a "$ta" "$id" "$from_b" || fail "the admin of a.example.test does not read the message of b.example.test"
from_a="hello from a.example.test $RANDOM"
send a "$ta" "$id" "$from_a"
reads b "$tb" "$id" "$from_a" || fail "the admin of b.example.test does not read the reply of a.example.test"
echo "@admin:a.example.test joined #fed:b.example.test ($id) and read '$from_b', @admin:b.example.test read '$from_a'"

# EX-33a: without the option federation on b.example.test the alias lookup
# gets 404.
restart b "$b_off"
room fed-off >/dev/null
status=$(join fed-off)
answer=$(<"$tmp/join")
[[ $status == 404 ]] || fail "with b.example.test without the option federation the join got $status, not 404: $answer"
echo "b.example.test without the option federation: the join got 404, $(jq -r .errcode <<<"$answer")"
restart b "$b_on"

# EX-33a: without ip_range_whitelist a.example.test finds no address for
# b.example.test.
restart a "$a_open"
ta=$(login a "$PASSWORD_A") || fail "the admin of a.example.test cannot log in after the restart"
room fed-open >/dev/null
status=$(join fed-open)
answer=$(<"$tmp/join")
[[ $status == 502 ]] || fail "with a.example.test without ip_range_whitelist the join got $status, not 502: $answer"
echo "a.example.test without ip_range_whitelist: the join got 502, $(jq -r .errcode <<<"$answer")"
