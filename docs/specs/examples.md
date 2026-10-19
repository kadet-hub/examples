# Examples

Status: Draft
Code: `*/check`, `apiserver-dry-run/dry-run`, `recipes/`, `recipes/tests/`, `argocd-vs-flux/`, `helm-mutate/`, `.github/workflows/examples.yml`, `renovate.json`
Verified against: main @ tbd

Each folder holds the runnable part of one kadet-hub.org blog post or
guide. A post or guide states results: identical manifests from three
tools, documents the API server rejects, a verified and schema-valid
compile. Those results depend on tool
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
  `talos-machine-config` fails on such a mismatch, on a node config that
  `talosctl validate --mode metal` rejects, when the nameserver or NTP
  server set once in the class `talos.cluster` is missing from a node's
  config, when dropping the class `talos.patches.worker-1-nvme` changes any
  file but `worker-1.yaml`, and when a control plane endpoint without
  scheme passes `talosctl validate`.

  `talos-machine-config/check` creates the cluster secrets with
  `talosctl gen secrets` on every run, writes them to Kapitan refs with the
  base64 backend and compiles with `--reveal`, because `talosctl validate`
  rejects placeholder certificates. Neither the refs nor the compiled
  configs are committed.

  `helm-vs-terraform` compiles one inventory into an OpenTofu root module
  (terraform-aws generator) and Kubernetes manifests (kubernetes
  generator). It fails unless the bucket name and region planned by
  `tofu plan` equal the app's ConfigMap data, both before and after the
  two values are changed in the target alone. Its `terraform-only` module
  writes the same ConfigMap with Terraform's own providers; the script
  fails unless `kubernetes_config_map_v1` and `helm_release` plan without
  a cluster, the `helm_release` plan carries the values but no rendered
  manifest, and `kubernetes_manifest` and the helm provider's `manifest`
  experiment fail to plan without one. A guide quotes these results, so a
  provider release that changes them fails the job.

  `argocd-vs-flux` fails unless EX-7 and EX-8 hold, `helm-mutate` unless
  EX-9 and EX-10 hold.

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

  Renovate updates a version and its checksum in the same pull request
  wherever the source allows it. Each pin uses one of three mechanisms:

  - Release asset: uv, oras, kubeconform, Pulumi, etcd, tk, jb, kind,
    chainsaw, talosctl and tofu are GitHub release assets. Their
    `# renovate:` comment names `datasource=github-release-attachments`,
    which hashes the matching asset of the new release. The pinned value
    MUST be the exact release tag, because the datasource looks the release
    up by it; URLs that need the bare number strip the `v` with `${X#v}`.
    The sha256 MUST be that of the downloaded file, not of a file inside
    it, or Renovate keeps the old hash without an error.
  - Image: kube-apiserver, kubectl and kustomize come from the Kubernetes
    project's images on registry.k8s.io, pinned as `tag@sha256:digest`
    with `datasource=docker`. The job copies the binary out with
    `docker create` and `docker cp`. The kube-apiserver and kubectl
    binaries are identical to the dl.k8s.io downloads; the kustomize binary
    is a separate build of the same version.
  - Check: helm, Node.js, gVisor, `openapi2jsonschema.py` and the Pulumi
    Kubernetes plugin have neither a release asset nor an image published
    by the project (the Docker Hub `node` image is built by Docker's
    Official Images program). Renovate bumps the version only. On Renovate
    pull requests the `pins` job compares each checksum with the
    publisher's checksum file (helm `.sha256sum`, Node.js `SHASUMS256.txt`,
    gVisor `.sha512`, the plugin's `checksums.txt` at the locked
    `@pulumi/kubernetes` version) or, for `openapi2jsonschema.py`, which
    has none, with the hash of the file at the pinned kubeconform tag, and
    fails with the line to paste.

  The release-asset and the version-only comments are separate match
  strings: `github-releases` also returns digests, a commit SHA, which it
  would write into a `_SHA256` field.

  Kapitan and Python packages are pinned by version through uv, npm packages
  through `package-lock.json`, jsonnet libraries through
  `jsonnetfile.lock.json`. `talosctl` is pinned by the sha256 that the
  Siderolabs release lists in `sha256sum.txt`. `gh`, `jq`, `curl`,
  `openssl`, `python3` and `docker` come from the runner image. kind runs
  the node image its release names, pinned by digest in `recipes/check` and
  `argocd-vs-flux/check`; the release manifests of the operators without a
  Helm chart (EX-5a), of Argo CD and of Flux are pinned by URL and sha256
  there. Operator charts are pinned in the recipes' operator classes by
  version and the digest of their OCI artifact, operator images by
  `tag@sha256:digest`; a regex manager in `renovate.json` updates both with
  `datasource=docker`, and one package rule puts the chart and the images
  of one operator class into one pull request, so that a chart's CRDs never
  run with another operator version. Kapitan 0.36.3 with the `omegaconf`
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

  The Terraform examples run OpenTofu (MPL-2.0) rather than Terraform
  (BUSL-1.1, not an open source license). Its
  providers are pinned by version in the configuration and by hash in a
  committed `.terraform.lock.hcl`, which `tofu init -lockfile=readonly`
  enforces. `tofu plan` runs with dummy AWS keys and the provider's
  `skip_*` flags, so it contacts no AWS endpoint, and without a
  kubeconfig, so it contacts no cluster.

  - Test: `manual:` review of `.github/workflows/examples.yml` and the `check` scripts;
    `renovate --platform=local --dry-run=lookup` with pins set one release
    back; workflow job `pins`
  - Since: tbd; checksums by Renovate: #15; operator charts and images: #21

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

  The MySQL image is Oracle's `container-registry.oracle.com/mysql/community-server`,
  built by the MySQL team, rather than the Docker Official Image `mysql`,
  which docker-library builds from Oracle's packages. MongoDB Community
  Server is licensed SSPLv1, which the OSI does not count as open source;
  its image `mongodb/mongodb-community-server` is MongoDB Inc's, and the
  recipe states the license in its class. Oracle's MySQL Operator (UPL-1.0)
  and MongoDB's Controllers for Kubernetes (Apache-2.0 for Community
  deployments) have no kadet-hub generator, so both recipes use the
  kubernetes generator and their class names the operator as the option
  for replication.

  - Test: `recipes/check` (fails on a dependency without a digest and on
    `bitnami` in a class or the compiled output)
  - Since: #8, #20

- EX-5a: A recipe whose resources need an operator MUST install it from
  the project's Helm chart through an operator class
  `recipes/inventory/classes/recipes/operators/<operator>.yml`, where the
  project publishes one.

  An operator class pins the chart's OCI artifact by version and digest in
  a Kapitan `helm` dependency and renders it with the `helm` input into
  `operators/<operator>`. Where the chart needs a change its values cannot
  make, the mutate generator runs as a second compile entry on the same
  `output_path` with `output_type: plain`, as in `helm-mutate`. The class
  adds the operator's namespace to the kubernetes generator's namespaces.
  CloudNativePG, cert-manager and Strimzi run in their own namespaces and
  watch every namespace, so a target that combines recipes installs each
  once, as it compiles a generator once.

  The operator image is pinned as `tag@sha256:digest`. CloudNativePG's
  values take a tag only, so mutate sets the reference in the container
  and in `OPERATOR_IMAGE_NAME`, which the operator gives the instance
  pods. Strimzi's values take a digest but then drop the tag, so mutate
  sets the reference in the container and in the three variables that run
  the same image for the entity operator and the Kafka init container.
  cert-manager's values take tag and digest for each image, so its class
  has no mutate entry. The Keycloak Operator's take the whole reference;
  its mutate entry sets the namespace of the Deployment, the Service, the
  ServiceAccount and one RoleBinding, which the chart leaves to `helm
  install --namespace`, so that `kubectl apply` does not put them into
  `default`.
  The cert-manager class sets `crds.enabled` and leaves out
  `startupapicheck`, a Helm hook that waits for the webhook during `helm
  install`. The images the operators start for the software, PostgreSQL,
  Kafka and Keycloak, stay pinned by tag in the recipe classes (EX-5).

  The Keycloak Operator's chart, `oci://quay.io/keycloak/keycloak-operator-helm`,
  is marked experimental by the project and defaults to watching every
  namespace, which the project calls a preview. The class keeps the chart
  and sets the four controllers to `JOSDK_WATCH_CURRENT`, so the operator
  runs in `keycloak` and watches that namespace only, as its release
  manifests install it.

  The RabbitMQ Cluster Operator has no Helm chart from its project (checked
  2026-10-19): rabbitmq/cluster-operator publishes release manifests and
  Kustomize bases, and Bitnami's `rabbitmq-cluster-operator` chart is
  excluded by EX-5. `recipes/check` installs it from its pinned release
  manifest, which the recipe class names; cert-manager, which issues its
  webhook certificate, comes with the recipe from its chart.

  `check` fetches the charts with `kapitan compile --fetch -t charts`:
  target `charts` includes every operator class and no generator, so EX-4
  holds as for `helm-mutate`'s target `helm`; it is not a recipe. The
  operators are applied server-side, because their CRDs exceed the
  annotation size of a client-side apply, and before the generators'
  output, which needs their CRDs and webhooks. kubeconform skips
  `CustomResourceDefinition`, for which the generators carry no schema,
  and validates the rest of the chart output.

  - Test: `recipes/check` via the `examples` workflow, job `recipe` for
    `postgresql`, `keycloak`, `kafka` and `rabbitmq` (fails when helm rejects a chart's
    digest, a mutation matches nothing, or the operator does not come up)
  - Since: #21

PowerDNS keeps its zones in SQLite on a volume rather than in PostgreSQL:
the image ships the SQLite schema, while the PostgreSQL backend would need
the schema loaded through CloudNativePG's post-init SQL, one more moving
part in a recipe whose subject is external-dns.

- EX-6: CI MUST, for every recipe, apply the operators the recipe compiled
  (EX-5a), and install those without a Helm chart from their pinned release
  manifests, into a new kind cluster, apply the compiled target and fail
  unless the recipe's check passes within its time limit. It MUST fail
  within about a minute once a pod is broken.

  A pod is broken when one of its containers waits with
  `CrashLoopBackOff`, `ImagePullBackOff`, `CreateContainerConfigError` or
  `InvalidImageName`, or has restarted more
  than three times, on two polls in a row. One poll is not enough:
  Argo CD's server waits with `CreateContainerConfigError` for the
  `argocd-redis` Secret until the redis pod's init container has created
  it, and the watcher stopped a healthy install on that in CI. `recipes/check` polls the pods of all namespaces every
  10 seconds from the creation of the kind cluster until Chainsaw ends, so
  a broken pod also stops the operator installs. On the first broken pod
  it prints the pod's description and its containers' logs and stops the
  command `check` waits for, an operator's `rollout status` or `wait`, or
  Chainsaw.
  The watch sits in `check` because Chainsaw runs the operations of a test
  one after another and has none that runs beside an assert.

  When a `rollout status` or `wait` of an operator times out, `check` prints the
  namespace's events sorted by time, `kubectl get pods -o wide`, and the
  description and logs of every pod that is not ready. Without them the
  timeout names only the Deployments that did not become available.

  Every apply, of an operator's release manifest as of the compiled output,
  is repeated for up to a minute until the API server accepts it. A webhook
  can refuse connections for a few seconds after its rollout reports done,
  because the deployment's readiness probe checks another port: the
  RabbitMQ Cluster Operator's probe is `/readyz` on 8081 while its webhook
  listens on 9443, and cert-manager's webhook rejected the Certificates of
  the RabbitMQ operator's manifest in CI ("failed calling webhook
  webhook.cert-manager.io") right after `rollout status` returned. `kubectl
  apply` is idempotent, so a repeat changes nothing that already exists. A
  server-side dry run, used before, cannot pass for a manifest that creates
  its own Namespace and so always waited the full minute.

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
    by hand, with a non-existent image tag in a recipe class or in an
    operator's release manifest
  - Since: #8, #10, #13, #16, #17, #20; operators from the compiled target: #21

## Argo CD and Flux

`argocd-vs-flux/` backs the kadet-hub.org guide that compares the two
delivery tools. The guide states what each one needs installed, how long the
same app takes to come up and what each does when someone changes a
deployed object by hand. One Kapitan project renders the app with the
kubernetes generator, an Argo CD Application with the argocd generator and a
GitRepository plus Kustomization with the flux generator; `check <tool>`
runs one tool per kind cluster, so the two never manage the same objects.

Both tools read the compiled app from a Gitea in the cluster, not from
GitHub. The commit they deploy has to exist before the check runs, and a
commit of this repository reaches GitHub only after the push, so a local
run or a pull request could not deploy its own change. `check` pushes
`compiled/web` as one commit to `main` of that server and expects both tools
to report exactly that commit. The Gitea image is pinned by digest in
`argocd-vs-flux/git-server.yaml`.

- EX-7: CI MUST, for Argo CD and for Flux, install the tool from its pinned
  release manifest into a new kind cluster, apply the tool's compiled
  target and fail unless, within the time limit, the Application is
  `Synced` and `Healthy` (Flux: the Kustomization is `Ready`) at the pushed
  commit and the app's Deployment has all replicas available.

  The generators are verified and fetched as in EX-4. Broken pods stop the
  check and a timed-out install wait prints its namespace as in EX-6, for
  the Git server and the tool as for an operator. `check` replaces Argo
  CD's redis image `public.ecr.aws/docker/library/redis:8.2.3-alpine` with
  `mirror.gcr.io/library/redis:8.2.3-alpine` pinned by the same digest
  (`sha256:08ad0b1d…`, identical on ECR Public, Docker Hub and the mirror,
  checked 2026-10-19): ECR Public answered anonymous pulls from GitHub
  runners with "429 Too Many Requests" in three of four runs, and the
  manifest pulls redis with `imagePullPolicy: Always`, so a pull before the
  install would not help. The Argo CD Application syncs automatically with
  `prune` and `selfHeal`; the Flux objects keep the flux generator's
  defaults plus `prune: true`. `check` prints the numbers the guide quotes:
  the CRDs in the release manifest, the tool's pods and images, the seconds
  from applying the manifest until its Deployments are available, the
  seconds from creating the Application or Kustomization until the app's
  Deployment is available, and the memory working set of the tool's pods
  after the check, read from the kubelet summary API.

  - Test: `examples` workflow, job `argocd-vs-flux` per tool
  - Since: #14, #16

- EX-8: The check MUST scale the app's Deployment to one replica with
  `kubectl scale` and fail unless Argo CD restores two replicas within a
  minute on its own, and unless Flux keeps one replica for 30 seconds and
  restores two within a minute of a requested reconciliation.

  Argo CD watches the objects it deployed and, with `selfHeal`, syncs back
  on a difference. Flux's kustomize-controller applies the source again on
  its interval, 60 minutes for this Kustomization, or when the
  `reconcile.fluxcd.io/requestedAt` annotation changes, which is what
  `flux reconcile kustomization` sets. The 30 seconds show that Flux does
  not react to the change in between, not that it never would.

  - Test: `argocd-vs-flux/tests/<tool>/chainsaw-test.yaml`, second step
  - Since: #14

## Helm chart patched with mutate

`helm-mutate/` backs the kadet-hub.org guide on patching a Helm chart
without forking it. One Kapitan project fetches podinfo's chart through
Kapitan's `helm` dependency, renders it with the `helm` input and patches
the output with the mutate generator, a second compile entry on the same
`output_path` with `output_type: plain`. Target `helm` renders the chart
alone, target `podinfo` renders and mutates it, targets `argocd` and `flux`
deliver `compiled/podinfo` as in `argocd-vs-flux`, from the same Git server
manifest.

The dependency names the chart's OCI artifact by digest and the version
6.15.0. Kapitan's `helm` dependency has no digest or verify field; it
passes source and version to `helm pull`, and Helm 4.3.0 fails with
"chart reference digest mismatch" when the tag points to another digest.
The OCI chart is also signed with cosign and Notation; `check` verifies
neither, because Kapitan's dependency has no place for it and it would add
a tool. The HTTP repository publishes no `.prov` files, and Kapitan does
not pass `--verify`.

`check` fetches the chart with `kapitan compile --fetch -t helm`. Target
`helm` declares the chart and no generator, so EX-4 holds; the generators
are verified and pulled by digest before.

Kapitan's `helm` input passes `--skip-tests` unless the entry sets
`skip_tests: false`, which the class does, so that the chart's three helm
test Pods are rendered and the mutation `no-test-pods` has whole files to
empty. Their names end in five random characters (`randAlphaNum`), so the
mutation matches them by kind and label, not by name.

- EX-9: `helm-mutate/check` MUST fail unless the compiled target `podinfo`
  carries the change of each mutation, each test Pod file is the single
  comment line of MUT-3 (kadet-hub/generators `docs/specs/mutate.md`), a
  mutation whose `match` names a Deployment the chart does not render
  fails the compile with `expects 1+, matched 0`, and kubeconform passes.

  The mutations are `pin-image` (`images`, the podinfo image by digest),
  `harden` (`merge` with `merge_lists: {containers: name}`: restricted
  `securityContext` and a memory limit, the chart's requests and env
  kept), `service-owner` (an annotation on every Service, matched by kind
  only), `replicas` (`json6902`: `test` that the chart renders one
  replica, then `replace` with two) and `no-test-pods` (`delete`). The
  failing mutation is added to a copy of the inventory in a temporary
  directory, never to a committed target. `check` prints the diff between
  the two renders with both sides loaded and dumped again with sorted
  keys, so that mutate's reformatting of a rewritten file does not show.

  - Test: `examples` workflow, job `helm-mutate`
  - Since: #19

- EX-10: CI MUST deploy `compiled/podinfo`, comment-only files included, to
  a new kind cluster once with `kubectl apply -R -f`, once through Argo CD
  and once through Flux, and fail unless the patched Deployment has two
  available replicas in a namespace that enforces restricted Pod Security,
  the Service carries the annotation, no helm test Pod exists, and the
  Application is `Synced` and `Healthy` (Flux: the Kustomization is
  `Ready`) at the pushed commit.

  A file that holds only a comment is the case to prove. Argo CD reads the
  path as a directory source with `recurse: true`. Flux's
  kustomize-controller finds no `kustomization.yaml` and generates one
  that lists every `.yaml` file kustomize's resource factory decodes
  without error; a comment decodes to zero objects. The restricted
  namespace admits podinfo's Pods only with the `harden` mutation, because
  the chart's defaults set no `securityContext`; the image's user is the
  name `app`, so `harden` sets a numeric `runAsUser` for `runAsNonRoot`.
  Install pins, the redis image rewrite and the failure output are those
  of EX-6 and EX-7.

  - Test: `helm-mutate/tests/<tool>/chainsaw-test.yaml`; `examples`
    workflow, job `helm-mutate` per tool
  - Since: #19

## Open questions

- OQ-1: Python interpreters are downloaded by uv and package versions come
  from PyPI without a hash pin outside `first-platform/uv.lock`. Is a uv lock
  per example worth the extra files?
- OQ-2: `apiserver-dry-run/check` validates against the Kubernetes schemas
  from the default kubeconform location, which tracks the `master` branch of
  yannh/kubernetes-json-schema.
- OQ-3: Should `helm-mutate/check` verify the podinfo chart's cosign
  signature in addition to the digest pin? It would add cosign to the job.
  Renovate updates neither the chart digest nor the image digest of
  `pin-image`; both are set by hand with the version.
- OQ-4: Should the RabbitMQ Cluster Operator come with its recipe without
  a chart? Its manifest exists only as a release asset, which Kapitan's
  `https` dependency fetches without a checksum, and a `copy` entry with
  mutate would apply it.

## Inventory

| Path | Content |
|---|---|
| `.github/workflows/examples.yml` | One job per example, tool versions, sha256 and images in `env`; job `pins` (EX-3) |
| `renovate.json` | Org preset for generator pins, regex manager for `# renovate:` comments |
| `apiserver-dry-run/.github/workflows/dry-run.yml`, `first-platform/.github/workflows/compile.yml` | Templates shown in the posts; GitHub does not run them here |
| `talos-machine-config/` | One Kapitan project, target `lab` with three Talos nodes; `check` verifies the generator, fills the refs, compiles and runs `talosctl validate` |
| `helm-vs-terraform/providers/.terraform.lock.hcl`, `helm-vs-terraform/terraform-only/.terraform.lock.hcl` | Provider hashes; the first is copied into the compiled root module |
| `recipes/` | One Kapitan project; `check <recipe>` verifies the generators, compiles, deploys to kind and runs the recipe's check |
| `recipes/inventory/classes/recipes/operators/` | One class per operator with a Helm chart: chart pin, `helm` and `mutate` entries, image pins (EX-5a) |
| `recipes/inventory/targets/charts.yml` | Every operator class and no generator, for `check` to fetch the charts (EX-4, EX-5a) |
| `argocd-vs-flux/` | One Kapitan project (targets `web`, `argocd`, `flux`), the Gitea manifest and a Chainsaw test per tool; `check <argocd\|flux>` |
| `helm-mutate/` | One Kapitan project (targets `helm`, `podinfo`, `argocd`, `flux`), the podinfo chart pinned in `inventory/classes/podinfo.yml`, the mutations in `inventory/targets/podinfo.yml`, a Chainsaw test per tool; `check <kubectl\|argocd\|flux>` |

Recipes and their checks:

| Recipe | Replaces (Bitnami) | Generators | Operators | Check |
|---|---|---|---|---|
| `postgresql` | postgresql, postgresql-ha | cloudnative-pg, mutate | CloudNativePG (chart) | Cluster `Ready`, `select 1` as the app user through the pooler |
| `keycloak` | keycloak | keycloak, cloudnative-pg, certmanager, mutate | Keycloak Operator, CloudNativePG, cert-manager (charts) | Keycloak `Ready`, `/realms/master` answers 200 over TLS |
| `valkey` | redis | kubernetes | none | StatefulSet ready, `valkey-cli ping` answers `PONG` |
| `kafka` | kafka | strimzi, mutate | Strimzi (chart) | Kafka `Ready`, a message produced and consumed |
| `rabbitmq` | rabbitmq | rabbitmq | RabbitMQ Cluster Operator (release manifest), cert-manager (chart) | RabbitmqCluster `AllReplicasReady` |
| `external-dns-powerdns` | external-dns | kubernetes | none | a Service hostname resolves through PowerDNS |
| `mysql` | mysql | kubernetes | none | StatefulSet ready, `select 1` as the app user in its own database |
| `mongodb` | mongodb | kubernetes | none | StatefulSet ready, `mongosh` authenticates and `ping` answers `ok: 1` |
