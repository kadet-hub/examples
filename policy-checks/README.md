# policy-checks

Policy checks on Kapitan's compiled output before it reaches a cluster:
the Kyverno CLI with policies from
[kyverno/policies](https://github.com/kyverno/policies), and conftest with
Rego rules of your own. The same Kyverno policies then run at admission in
a kind cluster. Written up at
https://kadet-hub.org/blog/kyverno-cli-conftest-ci/.

| Path | Content |
|---|---|
| `inventory/classes/web.yml` | podinfo as a Deployment with a Service, the kubernetes generator pinned by digest |
| `inventory/targets/compliant.yml` | Image by tag and digest, requests and a memory limit, the generator's restricted security profile, a PodDisruptionBudget |
| `inventory/targets/noncompliant.yml` | The `latest` tag, no resources, a privileged container, no PodDisruptionBudget |
| `policy/compiled.rego` | conftest rules over one target: images pinned by digest, a PodDisruptionBudget for every Deployment with more than one replica |
| `.github/workflows/policy.yml` | The pull request workflow for a repository of your own; GitHub does not run this copy |

## Running

```sh
# gh (logged in), jq, oras, uv, kyverno, conftest, kind, kubectl, curl and docker on PATH
./check
```

`check` verifies the latest signed index and the generator's attestation,
pulls the generator by digest into `lib/` and compiles both targets.
`kapitan compile` exits 0 for `noncompliant` and logs two warnings. The
Kyverno CLI then runs the best-practice policies `disallow-latest-tag` and
`require-pod-requests-limits` and the Pod Security Standards `baseline`
and `restricted` policies of kyverno/policies, at the commit pinned in
`check`, on every file of each target. conftest runs `policy/` with
`--combine` on each target. Both must pass `compliant` and fail
`noncompliant`.

`check` then installs Kyverno at the CLI's version into a kind cluster
and applies the same policies. The API server must reject
`noncompliant`'s Deployment once the policies deny, admit it while they
audit, as kyverno/policies ships them, roll out `compliant`, and reject a
privileged `kubectl run`. `KEEP=1 ./check` keeps the cluster
`policy-checks`.

## Using it

Copy `policy/` and `.github/workflows/policy.yml` to the root of a
repository whose Kapitan project the registry's
[consumer workflow](https://github.com/kadet-hub/registry/blob/main/docs/consumers.md)
compiles, next to its compile diff workflows. The policy job reads the
artifact `compiled` of the consumer workflow and treats every YAML file in
it as a Kubernetes object.
