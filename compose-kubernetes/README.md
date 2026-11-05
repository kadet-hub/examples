# compose-kubernetes

Miniflux, a feed reader, and its PostgreSQL database, from one Kapitan
inventory to a Kubernetes cluster and to a Docker host. Both targets
include the same class, built on the published kadet-hub recipe
`miniflux`. The target `cluster` compiles with the kubernetes generator,
the target `compose` with a kadet component in this folder that writes a
Docker Compose file. Written up at
https://kadet-hub.org/blog/docker-compose-kubernetes/.

| Path | Content |
|---|---|
| `fetch/targets/recipes.yml` | The recipe by version and digest, in the fetch inventory format of the registry's [consumer docs](https://github.com/kadet-hub/registry/blob/main/docs/consumers.md#recipes) |
| `inventory/classes/miniflux.yml` | What both targets share: the recipe's two components and the credentials as refs |
| `inventory/targets/cluster.yml` | The recipe's kubernetes compile, the Namespace `miniflux` with the Pod Security level `baseline`, and a readiness probe for Miniflux, which the recipe lacks |
| `inventory/targets/compose.yml` | The compile entry of `components/compose` and what only a Docker host needs: published port, start order, restart policy |
| `components/compose/__init__.py` | Maps the component keys the recipe uses to Compose services and fails on any other key |
| `.kapitan` | The omegaconf inventory backend, which the recipe is written for |

## Running

```sh
# gh (logged in), jq, oras, uv, kind, kubectl, curl and docker with the compose plugin on PATH
./check
```

`check` verifies the latest signed index and the attestation of the
recipe and of the generator it pins, pulls them by digest into
`inventory/classes/recipes/` and `lib/`, and compiles both targets. The
passwords are refs with the base64 backend in a temporary refs path, so
every run gets new random values. Before anything runs, it sets another
image in a copy of the shared class and requires exactly the image line of
the Deployment and of `compose.yml` to change. It also requires the target
`compose` to refuse `security_profile`, a Kubernetes-only key, in the
shared class. It then deploys `cluster` to a new kind cluster and starts
`compose` with `docker compose up`, revealed as under Using it. On both,
Miniflux must answer its health check, report the recipe's version and
store and list a category through its API as the admin. `KEEP=1 ./check`
keeps the cluster `compose-miniflux` and the compose project
`compose-ex-miniflux`.

## Using it

On a Docker host, compile without `--reveal` and reveal on the host, so
that no file holds the passwords:

```sh
kapitan compile -t compose
kapitan refs --reveal -f compiled/compose/compose.yml | docker compose -p miniflux -f - up -d
```

A key the target `compose` cannot map fails its compile with `no Compose
mapping for`. Put such a key, and anything else only one runtime needs,
in that runtime's target.
