# examples

Runnable examples behind the posts on the [kadet-hub.org blog](https://kadet-hub.org/blog/)
and its [guides](https://kadet-hub.org/guides/). Each folder belongs to one
page and has a script that exits non-zero when what the page claims no
longer holds.

| Folder | Page | Script |
|---|---|---|
| [same-app](same-app/) | https://kadet-hub.org/blog/same-app/ | `same-app/check` |
| [apiserver-dry-run](apiserver-dry-run/) | https://kadet-hub.org/blog/apiserver-dry-run/ | `apiserver-dry-run/check` |
| [first-platform](first-platform/) | https://kadet-hub.org/blog/first-platform/ | `first-platform/check` |
| [bitnami](bitnami/) | https://kadet-hub.org/blog/bitnami/ | `bitnami/run.sh` |
| [verify-oci](verify-oci/) | https://kadet-hub.org/blog/verify-oci/ | `verify-oci/verify kubernetes 1.2.0 47` |
| [gvisor-ci](gvisor-ci/) | https://kadet-hub.org/blog/gvisor-ci/ | `gvisor-ci/check` |
| [config-tools](config-tools/) | https://kadet-hub.org/blog/config-tools/ | `config-tools/check` |
| [talos-machine-config](talos-machine-config/) | https://kadet-hub.org/guides/talos-machine-config/ | `talos-machine-config/check` |
| [helm-vs-terraform](helm-vs-terraform/) | https://kadet-hub.org/guides/helm-vs-terraform/ | `helm-vs-terraform/check` |
| [argocd-vs-flux](argocd-vs-flux/) | https://kadet-hub.org/guides/argocd-vs-flux/ | `argocd-vs-flux/check argocd`, `argocd-vs-flux/check flux` |
| [helm-mutate](helm-mutate/) | https://kadet-hub.org/guides/patch-helm-chart/ | `helm-mutate/check kubectl`, `helm-mutate/check argocd`, `helm-mutate/check flux` |
| [cert-manager-mutate](cert-manager-mutate/) | https://kadet-hub.org/blog/cert-manager-helm-chart-patches/ | `cert-manager-mutate/check` |

## Running

Run a script from anywhere, for example `same-app/check`. The comment at the
top of each script lists the tools it needs on `PATH`; the
[examples workflow](.github/workflows/examples.yml) pins their versions and
checksums. `gh` has to be logged in for every example that verifies
kadet-hub attestations: all but `apiserver-dry-run` and `gvisor-ci`.

`apiserver-dry-run/dry-run` is the script from the post and exits 1 on
purpose, because five of the manifests are broken. `apiserver-dry-run/check`
runs it and expects exactly those five to be rejected. In the same way,
`gvisor-ci/run` prints what the escape scripts do and `gvisor-ci/check`
compares that with the post.

`first-platform` is meant to be copied to the root of a repository: its
`.github/workflows/compile.yml` and `.kapitan-sandbox.yaml` only take effect
there.

## CI

The examples workflow runs every script on pull requests, on pushes to `main`
and weekly, so a change in a tool, a generator or the signed index that breaks
a post shows up as a failed run. Renovate updates versions and digests; for
pins Renovate cannot hash, the `pins` job prints the new hash on the Renovate
PR.

Requirements: [docs/specs/examples.md](docs/specs/examples.md).

## License

[Apache-2.0](LICENSE)
