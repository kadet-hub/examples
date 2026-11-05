# immich-cnpg

Immich, the self-hosted photo and video library, with PostgreSQL run by
the CloudNativePG operator, from the published kadet-hub recipes `immich`,
`postgresql`, `valkey` and `cnpg`. Written up at
https://kadet-hub.org/blog/immich-kubernetes/.

| Path | Content |
|---|---|
| `fetch/targets/recipes.yml` | The four recipes by version and digest, in the fetch inventory format of the registry's [consumer docs](https://github.com/kadet-hub/registry/blob/main/docs/consumers.md#recipes) |
| `inventory/targets/cnpg.yml` | The CloudNativePG operator and its CRDs in namespace `cnpg-system` |
| `inventory/targets/immich.yml` | Immich, its PostgreSQL Cluster with one instance and its Valkey in namespace `immich` |
| `.kapitan` | The omegaconf inventory backend, which the recipes are written for |

## Running

```sh
# gh (logged in), jq, oras, uv, kind, kubectl, curl and docker on PATH
./check
```

`check` verifies the latest signed index and the attestation of every
recipe and generator, pulls them by digest into
`inventory/classes/recipes/` and `lib/`, and compiles both targets. The
Valkey password is a ref with the base64 backend in a temporary refs path,
so every run gets a new random value. It then deploys `cnpg` and `immich`
to a new kind cluster and talks to Immich's API: it uploads four generated
JPEGs with EXIF dates and GPS positions, checks the timeline and the
reverse geocoding, shares an album with a second user, runs a smart
search, takes a database backup, copies the library claim and restores
the dump, and deletes the server pod and the PostgreSQL pod.
`KEEP=1 ./check` keeps the cluster `immich-cnpg`.

The five images are 1236 MB compressed for amd64 (sums of the layer
sizes, MB = 10^6 bytes): Immich's server 609, its machine learning 268,
PostgreSQL 275, Valkey 45 and the CloudNativePG operator 38.
