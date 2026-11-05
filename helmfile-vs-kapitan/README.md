# helmfile-vs-kapitan

The setup from [the post](https://kadet-hub.org/blog/helmfile-vs-kapitan/):
podinfo with Valkey as its cache, both from their upstream charts, in the
environments `dev` and `prod`. `helmfile/` deploys it with Helmfile,
`kapitan/` renders it with Kapitan's `helm` input and the kadet-hub
`kubernetes` generator. Both pin the charts at the same version and digest.

`./check` renders both environments with `helmfile template` and
`kapitan compile`, and fails unless the normalized manifests are equal.
It then deploys `prod` to a kind cluster, with `helmfile sync` and with
`kubectl apply` of Kapitan's output, and has podinfo store a key in Valkey.
Requirements: EX-21 in [docs/specs/examples.md](../docs/specs/examples.md).

The Valkey password exists only while `check` runs. Helmfile reads it from
`VALKEY_PASSWORD` through vals, Kapitan from a ref in a temporary refs
path. To render one side by hand:

```sh
VALKEY_PASSWORD=change-me helmfile -f helmfile/helmfile.yaml -e prod template --skip-tests
```

```sh
cd kapitan
printf %s change-me | kapitan refs --write base64:valkey/password -f -
kapitan compile --reveal
```

The Kapitan compile needs the charts in `kapitan/charts/` and the
generator in `kapitan/lib/kubernetes`. `check` puts them there, the
generator after verifying it against the signed index and its attestation.
