# same-app

The app from [the post](https://kadet-hub.org/blog/same-app/) rendered with
Helm (`helm/`), Helmfile (`helmfile/`, the same chart and values files),
Kustomize (`kustomize/`), Pulumi (`pulumi/`) and Kapitan (`kapitan/`). `./check` renders dev and prod with each tool and diffs the
normalized output against Kapitan's.

Pulumi renders without a cluster: the Kubernetes provider's
`renderYamlToDirectory` writes the manifests to `pulumi/rendered/<stack>`,
and the stacks `dev` and `prod` live in a local file backend in a temporary
directory, so no Pulumi Cloud account is needed. The provider omits
`initialDelaySeconds: 0`, so `check` drops that field from every rendering
before the diff.
