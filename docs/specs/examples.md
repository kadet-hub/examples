# Examples

Status: Draft
Code: `*/check`, `apiserver-dry-run/dry-run`, `recipes/`, `recipes/tests/`, `.github/workflows/examples.yml`, `renovate.json`
Verified against: main @ tbd

Each folder holds the runnable part of one kadet-hub.org blog post. A post
states results: identical manifests from three tools, documents the API server
rejects, a verified and schema-valid compile. Those results depend on tool
versions, generator releases and the signed index, all of which move after
the post is published. The repository therefore checks every claim on a
schedule instead of trusting the state on the publishing day.

## Checks

- EX-1: Each example folder MUST have a script that exits non-zero when the
  post's claim no longer holds.

  The script checks the claim itself, not only that the tools ran:
  `same-app` diffs the Helm, Kustomize and Pulumi renderings against
  Kapitan's, `config-tools` diffs its three renderings,
  `apiserver-dry-run` expects exactly the five broken documents to be
  rejected and the four valid ones to be created, `gvisor-ci` compares the
  escape scripts' output inside and outside the sandbox, `verify-oci` fails
  on an index or attestation mismatch, and `first-platform` and `bitnami`
  fail on such a mismatch and on any kubeconform finding.

  Before the diff, `same-app` drops the `app.kubernetes.io/managed-by`
  label, which names the tool, and `initialDelaySeconds: 0`, the API
  default: the Pulumi provider omits zero-valued fields, Kapitan's
  generator writes it.

  - Test: `examples` workflow, one job per folder
  - Since: tbd

- EX-2: CI MUST run every example's script weekly, in addition to pull
  requests and pushes to `main`.

  - Test: `examples` workflow, `schedule` trigger
  - Since: tbd

## Supply chain

- EX-3: Every tool the CI jobs download MUST be pinned by version and sha256,
  and every action by full commit SHA.

  Renovate bumps the versions through `# renovate:` comments; the sha256 next
  to a version is updated by hand, so a bump fails `sha256sum -c` until it is.
  Kapitan and Python packages are pinned by version through uv, npm packages
  through `package-lock.json`, jsonnet libraries through
  `jsonnetfile.lock.json`; `gh`, `jq`, `curl`, `openssl`, `python3` and
  `docker` come from the runner image. kind runs the node image its release
  names, pinned by digest in `recipes/check`; operator release manifests are
  pinned by URL and sha256 there. Kapitan 0.36.3 with the `omegaconf`
  extra MUST be installed with `omegaconf==2.4.0.dev4`: omegaconf 2.4.0
  breaks its OmegaConf backend (kapicorp/kapitan#1621).

  Pulumi's Kubernetes provider plugin is pinned by the `@pulumi/kubernetes`
  version in `same-app/pulumi/package-lock.json` and by the sha256 of its
  linux-amd64 archive in the workflow, which `same-app/check` passes to
  `pulumi plugin install --checksum`. `npm ci` runs with `--ignore-scripts`,
  because the package's install script downloads the plugin unchecked, and
  automatic plugin downloads are disabled during `pulumi up`. Pulumi keeps
  its state in a local file backend in a temporary directory; no Pulumi
  Cloud account is used.

  - Test: `manual:` review of `.github/workflows/examples.yml` and the `check` scripts
  - Since: tbd

- EX-4: Examples MUST NOT use `kapitan compile --fetch` unless the fetched
  generators were verified before.

  `--fetch` checks neither the index nor the attestations. The scripts verify
  the index signature and each artifact's attestation with the registry's
  release workflow identity, pull by digest with `oras` and compile without
  `--fetch`.

  - Test: `manual:` `grep -rn -- --fetch */check`
  - Since: tbd

## Recipes

`recipes/` replaces the most-starred Bitnami charts with inventory classes
for kadet-hub generators: the kubernetes generator for plain workloads, an
operator's generator where the project maintains an operator, or both. A
recipe is what a reader copies into a Kapitan project; kadet-hub.org shows
each one under `/recipes/`, read from this repository's `main` at build
time, so the page shows what this CI last checked.

A Bitnami chart's promise is that it deploys and comes up. Rendering and a
dry run prove that the YAML is valid, not that the app starts, so each
recipe is deployed to a kind cluster and checked for the state the table
under Inventory names.

- EX-5: Every recipe MUST be one class `recipes/inventory/classes/recipes/<name>.yml`
  and one target `recipes/inventory/targets/<name>.yml`, use only
  generators pinned by version and digest in
  `recipes/inventory/classes/generators.yml`, and use no Bitnami image or
  chart.

  Images come from the project that builds the software, pinned by tag in
  the class. Secrets a recipe generates, such as the Valkey password, are
  Kapitan refs created on the first compile; the recipes use the base64
  backend so they run anywhere, which encrypts nothing. Valkey stands in for Redis: Redis 8 and later are licensed
  RSALv2, SSPLv1 or AGPLv3, Valkey stays BSD-3-Clause and speaks the same
  protocol.

  - Test: `recipes/check` (fails on a dependency without a digest and on
    `bitnami` in a class or the compiled output)
  - Since: #8

PowerDNS keeps its zones in SQLite on a volume rather than in PostgreSQL:
the image ships the SQLite schema, while the PostgreSQL backend would need
the schema loaded through CloudNativePG's post-init SQL, one more moving
part in a recipe whose subject is external-dns.

- EX-6: CI MUST, for every recipe, install the operators the recipe needs
  from their pinned release manifests into a new kind cluster, apply the
  compiled target and fail unless the recipe's check passes within its
  time limit. It MUST fail within about a minute once a pod is broken.

  A pod is broken when one of its containers waits with
  `CrashLoopBackOff`, `ImagePullBackOff`, `CreateContainerConfigError` or
  `InvalidImageName`, or has restarted more
  than three times. `recipes/check` polls the pods of all namespaces every
  10 seconds while Chainsaw runs, so a broken operator counts too. On the
  first broken pod it prints the pod's description and its containers'
  logs and stops Chainsaw. The watch sits in `check` because Chainsaw runs
  the operations of a test one after another and has none that runs beside
  an assert.

  Before the output is applied, `check` repeats a server-side dry run of it
  for up to a minute until it passes: the RabbitMQ Cluster Operator has no
  readiness probe, so its rollout completes before its admission webhook
  listens, and an apply in that window fails with "connection refused".

  `ErrImagePull` alone does not count as broken: a registry hiccup causes
  it once, and a pull that keeps failing turns into `ImagePullBackOff`
  seconds later.

  Each test sets `spec.timeouts.assert` to three times the recipe's
  measured Chainsaw duration, at least 3 minutes. The `recipe` job's
  `timeout-minutes` of 15 covers the slowest recipe, about 3.5 minutes in
  CI, with room for image pulls on a cold runner.

  The generators are verified and fetched as in EX-4 before the compile.
  `recipes/check` owns the supply chain, the compile, the cluster and the
  operators; `recipes/tests/<recipe>/chainsaw-test.yaml` owns what is
  checked once the recipe is applied: assertions on the resources' status
  and a probe that uses the software, run by Chainsaw. On a failure
  Chainsaw prints the namespace's events, pod logs and the resources it
  waited for, which a timeout of `kubectl wait` does not.

  - Test: `examples` workflow, job `recipe` per recipe; the fail-fast path
    by hand, with a non-existent image tag in a recipe class
  - Since: #8, #10

## Open questions

- OQ-1: Python interpreters are downloaded by uv and package versions come
  from PyPI without a hash pin outside `first-platform/uv.lock`. Is a uv lock
  per example worth the extra files?
- OQ-2: `apiserver-dry-run/check` validates against the Kubernetes schemas
  from the default kubeconform location, which tracks the `master` branch of
  yannh/kubernetes-json-schema.

## Inventory

| Path | Content |
|---|---|
| `.github/workflows/examples.yml` | One job per example, tool versions and sha256 in `env` |
| `renovate.json` | Org preset for generator pins, regex manager for `# renovate:` comments |
| `apiserver-dry-run/.github/workflows/dry-run.yml`, `first-platform/.github/workflows/compile.yml` | Templates shown in the posts; GitHub does not run them here |
| `recipes/` | One Kapitan project; `check <recipe>` verifies the generators, compiles, deploys to kind and runs the recipe's check |

Recipes and their checks:

| Recipe | Replaces (Bitnami) | Generators | Operators | Check |
|---|---|---|---|---|
| `postgresql` | postgresql, postgresql-ha | cloudnative-pg | CloudNativePG | Cluster `Ready`, `select 1` as the app user through the pooler |
| `keycloak` | keycloak | keycloak, cloudnative-pg, certmanager | Keycloak Operator, CloudNativePG, cert-manager | Keycloak `Ready`, `/realms/master` answers 200 over TLS |
| `valkey` | redis | kubernetes | none | StatefulSet ready, `valkey-cli ping` answers `PONG` |
| `kafka` | kafka | strimzi | Strimzi | Kafka `Ready`, a message produced and consumed |
| `rabbitmq` | rabbitmq | rabbitmq | RabbitMQ Cluster Operator, cert-manager | RabbitmqCluster `AllReplicasReady` |
| `external-dns-powerdns` | external-dns | kubernetes | none | a Service hostname resolves through PowerDNS |
