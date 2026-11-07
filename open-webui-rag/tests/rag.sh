#!/usr/bin/env bash
# EX-31, EX-31a: retrieval through Open WebUI, Qdrant, LiteLLM and Ollama,
# which check deployed with tests/chainsaw-test.yaml.
# usage: rag.sh <chat model> <embedding model>, the Ollama models that
# LiteLLM routes the names chat and embedding to.
set -euo pipefail
fail() { echo "$*" >&2; exit 1; }
chat_model=$1 embedding_model=$2
cd "$(dirname "$0")"
pf=()
trap 'kill "${pf[@]}" 2>/dev/null' EXIT

# The fact that only tests/document.md holds, and the question about it.
code=4417-KESTREL
grep -qF "$code" document.md || fail "document.md does not hold $code"
question='What is the door code of the cold storage room in the kadet-hub test lab?'

forward() { # namespace service local-port:port health-path
  kubectl -n "$1" port-forward "service/$2" "$3" >/dev/null &
  pf+=($!)
  for _ in $(seq 30); do
    curl -fsS -o /dev/null "http://127.0.0.1:${3%%:*}$4" 2>/dev/null && return
    sleep 2
  done
  fail "no answer from the Service $2 through the port-forward"
}
forward open-webui open-webui 18080:80 /health
forward qdrant qdrant 16333:6333 /readyz
forward litellm litellm 14000:4000 /health/readiness
openwebui=http://127.0.0.1:18080 qdrant=http://127.0.0.1:16333 litellm=http://127.0.0.1:14000
qdrant_key=$(kubectl -n qdrant get secret qdrant-apikey -o jsonpath='{.data.api-key}' | base64 -d)
master_key=$(kubectl -n litellm get secret litellm-masterkey -o jsonpath='{.data.masterkey}' | base64 -d)

# Ollama starts without models.
for m in "$chat_model" "$embedding_model"; do
  t=$(date +%s)
  kubectl -n ollama exec deploy/ollama -- ollama pull "$m" >/dev/null 2>&1 || fail "ollama pull $m failed"
  echo "pulled $m in $(($(date +%s) - t))s"
done

# The first account becomes admin.
token=$(jq -n '{name: "Admin", email: "admin@example.com", password: "Check-Passw0rd"}' |
  curl -fsS --max-time 60 -H 'Content-Type: application/json' -d @- "$openwebui/api/v1/auths/signup" |
  jq -er 'select(.role == "admin") | .token')
api() { # path [curl arguments]
  local path=$1
  shift
  curl -fsS --max-time 600 -H "Authorization: Bearer $token" "$@" "$openwebui$path"
}

# The document goes into a knowledge base, which embeds it into Qdrant.
t=$(date +%s)
file=$(api '/api/v1/files/?process_in_background=false' -F file=@document.md | jq -er .id) ||
  fail "uploading document.md failed"
knowledge=$(api /api/v1/knowledge/create -H 'Content-Type: application/json' \
  -d '{"name": "Lab handbook", "description": "The test lab"}' | jq -er .id)
api "/api/v1/knowledge/$knowledge/file/add" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg id "$file" '{file_id: $id}')" >/dev/null || fail "adding document.md to the knowledge base failed"
echo "document.md in the knowledge base $knowledge in $(($(date +%s) - t))s"

# Open WebUI keeps every knowledge base in one Qdrant collection, with its
# id as tenant_id.
points=$(curl -fsS -H "api-key: $qdrant_key" -H 'Content-Type: application/json' \
  "$qdrant/collections/open-webui_knowledge/points/scroll" \
  -d "$(jq -nc --arg k "$knowledge" '{filter: {must: [{key: "tenant_id", match: {value: $k}}]}, limit: 100, with_payload: true, with_vector: true}')" |
  jq -c '.result.points')
jq -e --arg c "$code" 'length > 0 and any(.[]; .payload.text | contains($c))' <<<"$points" >/dev/null ||
  fail "Qdrant holds no point of the knowledge base with $code: $points"
point=$(jq -c --arg c "$code" 'first(.[] | select(.payload.text | contains($c)))' <<<"$points")
# The vector of that point against LiteLLM's embedding of its text.
embedding=$(curl -fsS -H "Authorization: Bearer $master_key" -H 'Content-Type: application/json' \
  "$litellm/v1/embeddings" -d "$(jq -nc --argjson p "$point" '{model: "embedding", input: $p.payload.text}')" |
  jq -c '.data[0].embedding')
cosine=$(jq -n --argjson a "$(jq -c .vector <<<"$point")" --argjson b "$embedding" '
  def dot(x; y): [range(x | length)] | map(x[.] * y[.]) | add;
  dot($a; $b) / ((dot($a; $a) * dot($b; $b)) | sqrt)')
jq -e --argjson c "$cosine" -n '$c > 0.999' >/dev/null ||
  fail "the vector in Qdrant is not LiteLLM's embedding of its text: cosine $cosine"
echo "Qdrant holds $(jq length <<<"$points") point(s) of the knowledge base, $(jq '.vector | length' <<<"$point") dimensions, cosine $cosine to LiteLLM's embedding of the text"

ask() { # files: Open WebUI's answer to the question
  api /api/chat/completions -H 'Content-Type: application/json' -d "$(jq -nc --arg q "$question" --argjson f "$1" \
    '{model: "chat", stream: false, temperature: 0, messages: [{role: "user", content: $q}], files: $f}')" |
    jq -er '.choices[0].message.content'
}
collection=$(jq -nc --arg k "$knowledge" '[{type: "collection", id: $k}]')
has_code() { grep -qiF "$code" <<<"$1"; }

t=$(date +%s)
answer=$(ask "$collection") || fail "the chat completion with the knowledge base failed"
has_code "$answer" || fail "with the knowledge base the answer lacks $code: $answer"
echo "with the knowledge base, in $(($(date +%s) - t))s: $(tr -s '[:space:]' ' ' <<<"$answer")"

answer=$(ask '[]') || fail "the chat completion without the knowledge base failed"
! has_code "$answer" || fail "without the knowledge base the answer still has $code: $answer"
echo "without the knowledge base: $(tr -s '[:space:]' ' ' <<<"$answer")"

# Without Qdrant the search of the knowledge base fails, Open WebUI logs
# that, and the model answers without the document.
kubectl -n qdrant scale statefulset/qdrant --replicas=0 >/dev/null
kubectl -n qdrant wait pod/qdrant-0 --for=delete --timeout=120s >/dev/null
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
answer=$(ask "$collection") || fail "the chat completion with Qdrant scaled to zero failed"
! has_code "$answer" || fail "with Qdrant scaled to zero the answer still has $code: $answer"
failed="query_collection: 1 collection(s) had failing queries: $knowledge"
kubectl -n open-webui logs open-webui-0 -c open-webui --since-time="$since" | grep -qF "$failed" ||
  fail "with Qdrant scaled to zero Open WebUI did not log: $failed"
echo "with the knowledge base and Qdrant scaled to zero, Open WebUI logged '$failed' and answered: $(tr -s '[:space:]' ' ' <<<"$answer")"
