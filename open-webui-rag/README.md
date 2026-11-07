# open-webui-rag

Retrieval-augmented generation (RAG) with Open WebUI, Qdrant, LiteLLM and
Ollama, from the published kadet-hub recipes `open-webui`, `qdrant`,
`litellm` and `ollama`, on one kind cluster. Written up at
https://kadet-hub.org/blog/open-webui-rag-kubernetes/.

`check` proves that a document added to a knowledge base in Open WebUI is
stored in Qdrant with the embeddings that LiteLLM gets from Ollama, and that
Open WebUI answers a question about it with the door code that only the
document holds. Asked without the knowledge base, or with Qdrant scaled to
zero, the answer lacks the code.

```sh
open-webui-rag/check
```

Needs `gh` (logged in), `jq`, `oras`, `uv`, `kind`, `kubectl`, `chainsaw`,
`curl` and `docker`. `KEEP=1` keeps the cluster `open-webui-rag`.

## How the parts connect

Open WebUI sends chat completions and embeddings to LiteLLM, which routes
the model names `chat` and `embedding` to `qwen2.5:0.5b` and
`nomic-embed-text:v1.5` in Ollama. Open WebUI stores the embedded chunks in
Qdrant and searches them there when a chat has the knowledge base attached.
Each recipe runs in a namespace of its own. The class
[`rag`](inventory/classes/rag.yml) holds the Service URLs, the two models,
the LiteLLM master key and the Qdrant API key, which the targets share.

Open WebUI 0.12.5 does not take the URL and key for embeddings from the
option `openai` of the recipe. The target sets `RAG_OPENAI_API_BASE_URL`
and `RAG_OPENAI_API_KEY`, the key from the Secret that the option writes.

## Layout

| Path | Content |
|---|---|
| `fetch/targets/recipes.yml` | `ollama`, `litellm`, `qdrant` and `open-webui`, by version and digest. `valkey`, which `open-webui` includes, and `postgresql`, which `litellm` includes, come at the digests of the index records. `postgresql` is not compiled. |
| `inventory/classes/rag.yml` | what the targets share |
| `inventory/targets/` | `ollama`, `litellm`, `qdrant` and `open-webui` |
| `tests/chainsaw-test.yaml`, `tests/namespaces.yaml` | the deploy, and the namespaces at Pod Security `baseline`, `restricted` for Qdrant |
| `tests/rag.sh`, `tests/document.md` | the knowledge base, the checks in Qdrant and LiteLLM, the three questions |

The five images are 5564 MB compressed for amd64 (sums of the layer sizes,
MB = 10^6 bytes): Ollama 3383, which carries the CUDA and ROCm libraries,
Open WebUI 1643, LiteLLM 420, Qdrant 73 and Valkey 45. `tests/rag.sh` pulls
the models into Ollama, 398 MB for `qwen2.5:0.5b` and 274 MB for
`nomic-embed-text:v1.5`.

The spec is EX-31 and EX-31a in
[docs/specs/examples.md](../docs/specs/examples.md).
