# argocd-cmp

Argo CD compiles a Kapitan project itself, through a config management
plugin that runs `kapitan compile` in a sidecar of the repo server. Nothing
compiles in CI and the Git repository holds no `compiled/` directory. The
project uses the published kadet-hub recipe `blackbox-exporter`. Written
up at https://kadet-hub.org/blog/argocd-config-management-plugin-kapitan/.

| Path | Content |
|---|---|
| `fetch/targets/recipes.yml` | The recipe by version and digest, in the fetch inventory format of the registry's [consumer docs](https://github.com/kadet-hub/registry/blob/main/docs/consumers.md#recipes) |
| `inventory/targets/blackbox-exporter.yml` | The target the Application names, with `replicas` set to 1 and the seccomp profile that the recipe leaves out |
| `.kapitan` | The omegaconf inventory backend, which the recipe is written for |
| `kapitan-plugin.yaml` | ConfigMap with the plugin configuration `plugin.yaml` |
| `repo-server-patch.yaml` | Strategic merge patch that adds the sidecar, Kapitan's image pinned by digest, to `argocd-repo-server` |
| `repo-server-egress.yaml` | NetworkPolicy that limits the repo server's egress to DNS, Redis and the Git server |
| `application.yaml` | The Application, with the plugin and the target in its env `TARGET` |
| `git-server.yaml` | Gitea, standing in for the Git server outside the cluster |

## Running

```sh
# gh (logged in), jq, oras, kind, kubectl, curl, openssl and docker on PATH
./check
```

`check` verifies the latest signed index and the attestation of the recipe
and of the generator it pins, and pulls them by digest into
`inventory/classes/recipes/` and `lib/`. It creates a kind cluster,
installs Argo CD from its release manifest, adds the plugin and the
sidecar, and checks that the sidecar has no service account token and
reaches ghcr.io until `repo-server-egress.yaml` applies. It pushes
`.kapitan`, `fetch/`, `inventory/` and `lib/` to the Git server as one
commit and creates the Application. Argo CD must report it `Synced` at
that commit and `Healthy`, rendered by the plugin, with one replica. Then
`check` sets `replicas` to 2 in the target, pushes, requests a refresh and
expects the same at the new commit with two replicas.
`KEEP=1 ./check` keeps the cluster `argocmp-argocd-cmp`.

## Using it

In a repository of your own, commit what `check` pulls: the sidecar
compiles without `--fetch`, so `lib/` and `inventory/classes/recipes/`
have to be in Git, verified as in the consumer docs. Point an Application
at the directory that holds `.kapitan`, with the plugin `kapitan` and the
target in `TARGET`. Everyone who can push to the branch it tracks runs
code in the sidecar, because kadet generators are Python and Jinja2
templates run on compile.
