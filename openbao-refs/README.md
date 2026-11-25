# openbao-refs

Kapitan refs moved from gpg to `vaultkv` refs in OpenBao, so that a CI job
and a workload in the cluster reveal them, each with its own OpenBao login
and without a copy of a private gpg key. Written up at
https://kadet-hub.org/blog/kapitan-refs-openbao/.

| Path | Content |
|---|---|
| `inventory/targets/app.yml` | The app's Secret with two `vaultkv` refs, and the `kapitan.secrets.vaultkv` block that every ref file of the target copies |
| `inventory/targets/openbao.yml` | OpenBao's dev server, standing in for an OpenBao that someone else runs, with the binding to `system:auth-delegator` that Kubernetes auth needs |
| `inventory/targets/deployer.yml` | A Job that logs in with Kubernetes auth and reveals the app's Secret, and a ServiceAccount `other` that no OpenBao role names |
| `inventory/classes/generators.yml` | The kubernetes generator, pinned by version and digest |
| `.kapitan` | The omegaconf inventory backend |

## Running

```sh
# gh (logged in), jq, oras, uv, gpg, kind, kubectl, openssl, curl and docker on PATH
./check
```

`check` verifies the latest signed index and the generator's attestation,
pulls the generator by digest and starts OpenBao in a kind cluster. It
sets up two policies on `secret/app`, an AppRole `ci` and a Kubernetes auth
role `deployer`. It writes two gpg refs with a key made for the run, moves
them to `vaultkv` refs and deletes the key. From there on, the compile runs
without OpenBao access, CI reveals with an AppRole token and applies the
Secret, and the Job reveals the same manifest in the cluster. A token with
the default policy only, an AppRole token without the default policy and
the ServiceAccount `other` must be refused. `KEEP=1 ./check` keeps the
cluster `openbao-refs`.

## Using it

In a repository of your own, commit `refs/` with the `vaultkv` ref files.
They hold a path and a key in OpenBao, not the values, so the values exist
only in OpenBao and its backups. Each consumer logs in to OpenBao its own
way and runs Kapitan with the token in `VAULT_TOKEN` and the address in
`VAULT_ADDR`.
