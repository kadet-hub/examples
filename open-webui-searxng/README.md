# open-webui-searxng

Open WebUI with SearXNG as its web search and Ollama for the model, from
the published kadet-hub recipes `open-webui`, `ollama`, `searxng` and
`valkey`. Written up at
https://kadet-hub.org/blog/open-webui-searxng-kubernetes/.

| Path | Content |
|---|---|
| `fetch/targets/recipes.yml` | The four recipes by version and digest, in the fetch inventory format of the registry's [consumer docs](https://github.com/kadet-hub/registry/blob/main/docs/consumers.md#recipes) |
| `inventory/targets/searxng.yml` | SearXNG in namespace `searxng`, with the JSON format Open WebUI asks for |
| `inventory/targets/open-webui.yml` | Open WebUI and Ollama in namespace `open-webui`, with SearXNG as the web search |
| `.kapitan` | The omegaconf inventory backend, which the recipes are written for |

## Running

```sh
# gh (logged in), jq, oras, uv, kind, kubectl, curl and docker on PATH
./check
```

`check` verifies the latest signed index and the attestation of every
recipe and generator, pulls them by digest into
`inventory/classes/recipes/` and `lib/`, and compiles both targets. The
secrets are refs with the base64 backend in a temporary refs path, so every
run gets new random values. It then deploys both targets to a new kind
cluster and talks to Open WebUI's API: a web search for `kubernetes`, a
pull of `smollm:135m` into Ollama, a chat completion, and the same web
search once more with SearXNG scaled to zero, which must fail.
`KEEP=1 ./check` keeps the cluster `open-webui-searxng`.

The four images are 5167 MB compressed for amd64 (sums of the layer
sizes, MB = 10^6 bytes): Ollama 3383, which carries the CUDA and ROCm
libraries, Open WebUI 1642, SearXNG 98 and Valkey 44.
