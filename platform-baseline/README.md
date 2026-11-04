# platform-baseline

A cluster's platform layer from one Kapitan inventory: cert-manager with a
private CA, a Kyverno policy, Prometheus and Grafana, External Secrets,
Velero and Argo CD, configured through kadet-hub generators, with podinfo on
top as the app that uses all of them. Written up at
https://kadet-hub.org/blog/kubernetes-cluster-add-ons/.

| Path | Content |
|---|---|
| `fetch/targets/recipes.yml` | The cert-manager recipe by version and digest, in the fetch inventory format of the registry's [consumer docs](https://github.com/kadet-hub/registry/blob/main/docs/consumers.md#recipes) |
| `inventory/classes/generators.yml` | The generators by version and digest; the kubernetes generator comes with the recipe |
| `inventory/classes/platform.yml` | The cluster-wide values every target reads: domain, issuer, secret store, namespaces, Git repository, the labels of app namespaces |
| `inventory/targets/` | One target per component: `cert-manager`, `kyverno`, `monitoring`, `external-secrets`, `velero`, `argocd`, and the app `podinfo` |
| `git-server.yaml`, `s3-server.yaml` | Gitea and Versity's S3 gateway, standing in for the Git server and the bucket outside the cluster |
| `.kapitan` | The omegaconf inventory backend, which the recipe is written for |

## Running

```sh
# gh (logged in), jq, oras, uv, kind, kubectl, velero, curl, openssl and docker on PATH
./check
```

`check` verifies the latest signed index and the attestation of the recipe
and of every generator, pulls them by digest into
`inventory/classes/recipes/` and `lib/`, and compiles the seven targets. It
compiles a copy of the inventory with another domain and expects exactly
the two certificates that name the domain to change. It then creates a kind
cluster, installs the operators from the recipe and from their projects'
release manifests, applies the platform targets and pushes
`compiled/podinfo` to the Git server, from which Argo CD deploys it.

The checks that follow go through the app: podinfo's HTTPS certificate
verifies against the platform CA and its response carries the message
from the secret store, Kyverno denies a pod whose image has no digest,
Prometheus and Grafana return podinfo's `up` series, a changed message
reaches podinfo's Secret, and Velero restores the deleted secrets
namespace.
`KEEP=1 ./check` keeps the cluster `platform-baseline`.
