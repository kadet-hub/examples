# multi-env

One app in dev, stage and prod from one Kapitan inventory, with dev and
stage on one cluster and prod on another. The app is the published
kadet-hub recipe `miniflux`, a feed reader with its own PostgreSQL. A
guard fails CI when prod differs from stage outside a list of allowed
fields. Written up at
https://kadet-hub.org/blog/kapitan-multiple-environments/.

| Path | Content |
|---|---|
| `fetch/targets/recipes.yml` | The recipe by version and digest, in the fetch inventory format of the registry's [consumer docs](https://github.com/kadet-hub/registry/blob/main/docs/consumers.md#recipes) |
| `inventory/classes/common.yml` | What every target runs: the recipe, prod's resources, refs per target, `BASE_URL` from `hostname`, the database's storage class from the cluster class |
| `inventory/classes/env/` | `hostname` and replicas per environment, smaller resources for dev |
| `inventory/classes/cluster/` | The cluster's name and storage class |
| `inventory/targets/` | `dev`, `stage` and `prod`, each with `common`, its env class and its cluster class; `dev` also sets its namespace, because it shares the cluster with stage |
| `guard`, `guard-allowed.txt` | The guard and the fields in which prod may differ from stage |
| `storage-class.yaml` | The StorageClass `local-retain` of the prod cluster, standing in for what a platform provides |
| `.kapitan` | The omegaconf inventory backend, which the recipe is written for |

## Running

```sh
# gh (logged in), jq, oras, uv, kind, kubectl, curl and docker on PATH
./check
```

`check` verifies the latest signed index and the attestation of the recipe
and of the generator it pins, pulls them by digest into
`inventory/classes/recipes/` and `lib/`, and compiles the three targets.
It runs the guard on stage and prod. In a copy of the project it adds one
setting to `env/dev.yml`, then to `env/stage.yml` and `env/prod.yml`,
compiles after each step and requires `diff -r` to show exactly one
changed target per step. The guard must refuse the stage step and accept
the prod step. Moving the setting into `common.yml` must change no file.
Then `check` creates the kind clusters `multienv-a` and `multienv-b`,
deploys each target to the cluster and namespace its inventory names, and
requires the replicas, memory limit, hostname and storage class each target
is set to. `KEEP=1 ./check` keeps the clusters.

## Using it

Run the guard after `kapitan compile` in CI:

```sh
python3 guard compiled/stage compiled/prod guard-allowed.txt
```

It needs PyYAML, which Kapitan brings. Compile without `--reveal`. The
guard counts ref tokens as equal, but it would print revealed secrets as
differing fields.
