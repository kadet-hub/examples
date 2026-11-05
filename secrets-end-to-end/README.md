# secrets-end-to-end

Vaultwarden from the published kadet-hub recipe `vaultwarden`, with two
kinds of secret. External Secrets syncs the admin token from Vault, so a
new token reaches the cluster without a compile. External Secrets logs in
to Vault with an AppRole, and its secret ID is the one secret the
inventory carries, as a Kapitan gpg ref. Written up at
https://kadet-hub.org/blog/external-secrets-operator-vault-kapitan/.

| Path | Content |
|---|---|
| `fetch/targets/recipes.yml` | The recipe by version and digest, in the fetch inventory format of the registry's [consumer docs](https://github.com/kadet-hub/registry/blob/main/docs/consumers.md#recipes) |
| `inventory/targets/vaultwarden.yml` | The target: the gpg recipient, the external-secrets generator, the Secret `vault-approle` with the ref, the SecretStore and the ExternalSecret, and the `remove` entry that drops the recipe's own Secret |
| `.kapitan` | The omegaconf inventory backend, which the recipe is written for |
| `vault-server.yaml` | Vault's dev server, standing in for a Vault outside the cluster |

## Running

```sh
# gh (logged in), jq, oras, uv, gpg, kind, kubectl, openssl and docker on PATH
./check
```

`check` verifies the latest signed index and the attestations of the
recipe and the generators, and pulls them by digest into
`inventory/classes/recipes/` and `lib/`. It creates a kind cluster,
installs External Secrets from its release manifest and starts the Vault
dev server. In Vault it stores an admin token, a policy that reads it and
an AppRole with that policy. It creates a gpg key for the run and writes
the AppRole's secret ID as the ref `gpg:vaultwarden/vault-secret-id`.
The compile without `--reveal` runs with an empty keyring and must hold
the ref's tag in place of the secret ID. The deploy reveals the ref with
the run's key and pipes it into `kubectl apply`. Vaultwarden's admin page
must accept the token from Vault. After a new token is written to Vault,
the Secret must follow, the running pod must still take the old token,
and after a restart only the new one.
`KEEP=1 ./check` keeps the cluster `secrets-end-to-end`.

## Using it

In a repository of your own, commit `refs/` with the gpg ref and keep the
private key where the deploy runs. A compile without `--reveal`, in CI for
example, needs neither key nor Vault access.
