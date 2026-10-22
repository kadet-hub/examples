# Examples

Status: Draft
Code: `*/check`, `gvisor-ci/run`, `apiserver-dry-run/dry-run`, `recipes/`, `recipes/tests/`, `argocd-vs-flux/`, `helm-mutate/`, `cert-manager-mutate/`, `first-platform/inventory/classes/shop.yml`, `helm-vs-terraform/inventory/classes/uploads.yml`, `.github/workflows/examples.yml`, `renovate.json`
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
  `same-app` diffs the Helm, Helmfile, Kustomize and Pulumi renderings
  against Kapitan's, `config-tools` diffs its three renderings,
  `apiserver-dry-run` expects exactly the five broken documents to be
  rejected and the four valid ones to be created, `gvisor-ci` compares the
  escape scripts' output inside and outside the sandbox and across Docker
  runtimes (EX-1a), `verify-oci` fails
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
  EX-9 and EX-10 hold, `cert-manager-mutate` unless EX-11 holds,
  `first-platform` and `helm-vs-terraform` unless EX-12 holds.

  Before the diff, `same-app` drops the `app.kubernetes.io/managed-by`
  label, which names the tool, and `initialDelaySeconds: 0`, the API
  default: the Pulumi provider omits zero-valued fields, Kapitan's
  generator writes it. `same-app` and `config-tools` also drop a Service
  port's `appProtocol`: the kubernetes generator derives it from the port
  name since 1.4.0, the other tools leave it unset.

  - Test: `examples` workflow, one job per folder
  - Since: tbd

- EX-1a: `gvisor-ci/check` MUST also run the three escape scripts under
  `docker run` with the default runtime and under `docker run
  --runtime=runsc`, every other option equal, and MUST fail unless both
  runtimes run the `fork_exec` child and both read the image's own
  `/etc/passwd`, and the two runtimes report a different kernel from
  `uname`.

  The post contrasts gVisor with a plain container, but the three defences
  run unconfined and under rootless `runsc`, never under Docker. Running
  the same scripts under Docker shows that swapping runc for runsc, with no
  other change, leaves what the scripts do unchanged: the child still runs
  and the read still returns the image's `/etc/passwd` under both. What
  differs is the kernel the process talks to, which `uname` reports as the
  host kernel under runc and as gVisor's own under runsc; the network and
  the spawn are bounded by `--network=none` and the trace, not by the
  runtime swap. `check` does not assert the cost figures or the raw-IP
  result, which vary by runner; the post quotes them from the run it cites.

  The comparison needs the `runsc` runtime registered in the Docker daemon,
  which the workflow does with `runsc install` and a daemon restart. That
  takes root, as the gate's trace runtime does, so the post's rootless
  `runsc ... do` form does not use it.

  - Test: `examples` workflow, job `gvisor-ci`; `gvisor-ci/check`
  - Since: #39

- EX-2: CI MUST run every example's script weekly, in addition to pull
  requests and pushes to `main`.

  - Test: `examples` workflow, `schedule` trigger
  - Since: tbd

- EX-12: CI MUST deploy every workload that an example renders to run to
  a new kind cluster and fail unless the workload becomes ready.

  kubeconform and an API server accept manifests that the kubelet cannot
  run, such as a readiness probe on a port the app does not listen on.
  `recipes`, `argocd-vs-flux`, `helm-mutate` and `cert-manager-mutate`
  deploy their workloads under EX-6, EX-7, EX-10 and EX-11.
  `first-platform/check` deploys `compiled/prod/apps` (Namespace,
  Deployment, Service, PodDisruptionBudget), `helm-vs-terraform/check`
  the Deployment, Service and ConfigMap of its first compile. Both create
  the namespace with `pod-security.kubernetes.io/enforce=restricted`,
  wait for `rollout status` of `deploy/web` and stop on a broken pod as
  in EX-6.

  The rest of `first-platform`'s output is not deployed. Its Certificates
  need cert-manager and an ACME server that reaches the hostnames, its
  CiliumNetworkPolicy needs Cilium as the CNI, and its Argo CD
  Application points to a Git server that does not exist. `dev` differs
  from `prod` only in replicas and the PodDisruptionBudget.

  The other examples have no workload of their own to deploy. `same-app`
  and `config-tools` render the placeholder images `ghcr.io/example/*`
  (EX-3a), `apiserver-dry-run` sends its documents to an API server
  without a kubelet, `talos-machine-config` renders node configs, and
  `verify-oci` and `gvisor-ci` render no manifests. `bitnami` renders a
  CloudNativePG Cluster with the same generator digest, name, namespace,
  image, instances, storage and bootstrap as the `postgresql` recipe,
  whose Cluster the `recipe` job deploys.

  podinfo listens on 9898 unless `--port` is set. Both classes start it
  as its chart does, `command: [./podinfo, --port=8080]`, on the
  container port that the readiness probe and, in `first-platform`, the
  CiliumNetworkPolicy use. `args` alone replaces the image's `CMD`, the
  only start command it has. The image names its user `app`, which the
  kubelet cannot verify against the restricted profile's `runAsNonRoot`,
  so both classes set `runAsUser: 65534`.

  Nothing runs `apiserver-dry-run`'s documents, but readers copy them.
  `manifests/web.yaml` therefore uses port 80, on which `nginx:1.29`
  listens, as container port and Service `targetPort`.

  Related: EX-6

  - Test: `examples` workflow, jobs `first-platform` and
    `helm-vs-terraform`; the other deploys as in EX-6, EX-7, EX-10 and
    EX-11; `manual:` `docker run --rm nginx:1.29 grep listen
    /etc/nginx/conf.d/default.conf` prints the port of
    `apiserver-dry-run/manifests/web.yaml`
  - Since: #34; `apiserver-dry-run` port: #36

## Supply chain

- EX-3: Every tool the CI jobs download MUST be pinned by version and sha256,
  and every action by full commit SHA. Renovate MUST update every pin in the
  repository, with its digest wherever a datasource provides one.

  Renovate updates a version and its checksum or digest in the same pull
  request. Each pin uses one of four mechanisms:

  - Release asset: uv, oras, kubeconform, Helmfile, Pulumi and its
    Kubernetes plugin, etcd, tk, jb, kind, chainsaw, talosctl, tofu and
    gVisor are GitHub release assets, and so are the install manifests of
    Flux and of the RabbitMQ Cluster Operator and the CRDs of cert-manager
    and Prometheus Operator in `chart-vs-kapitan`. Their `# renovate:` comment names
    `datasource=github-release-attachments`, which hashes the matching
    asset of the new release. The pinned value MUST be the exact release
    tag, because the datasource looks the release up by it; URLs that need
    the bare number strip the `v` with `${X#v}`. The sha256 MUST be that of
    the downloaded file, not of a file inside it, or Renovate keeps the old
    hash without an error.
  - Image: kube-apiserver, kubectl and kustomize come from the Kubernetes
    project's images on registry.k8s.io, pinned as `tag@sha256:digest`
    with `datasource=docker`. The job copies the binary out with
    `docker create` and `docker cp`. The kube-apiserver and kubectl
    binaries are identical to the dl.k8s.io downloads; the kustomize binary
    is a separate build of the same version. The check scripts pin kind's
    node image and the redis image of EX-7 the same way, `gvisor-ci/run`
    the image of its sandbox rootfs.
  - Commit: Argo CD's `install.yaml` and kubeconform's
    `openapi2jsonschema.py` are files in the projects' repositories, not
    release assets. They are fetched from raw.githubusercontent.com at the
    commit of the pinned tag, written `X_COMMIT=<sha> # <tag>` under a
    comment with `datasource=github-tags`, which updates tag and commit
    together, as for an action. No datasource hashes a file in a
    repository, so these two carry no sha256.
  - Check: helm, Node.js, and kube-apiserver and kubectl in the
    `apiserver-dry-run` workflow template, which downloads them from
    dl.k8s.io, have neither a release asset nor an image published by the
    project (the Docker Hub `node` image is built by Docker's Official
    Images program). Renovate bumps the version only. On Renovate pull
    requests the `pins` job compares each checksum with the publisher's
    (helm `.sha256sum`, Node.js `SHASUMS256.txt`, the dl.k8s.io binary)
    and fails with the line to paste.

  The release-asset, commit and version-only comments are separate match
  strings: `github-releases` and `github-tags` also return digests, a
  commit SHA, which they would write into a `_SHA256` field.

  Pins in Kapitan inventories and Kubernetes manifests are updated with
  `datasource=docker` by regex managers: generators through the org preset;
  charts by version and the digest of their OCI artifact (the operator
  classes, podinfo in `helm-mutate`, cert-manager and trust-manager in
  `cert-manager-mutate`); images wherever an `image:` or
  `image_name:` key or an `-image=` argument names one, by tag or by
  `tag@sha256:digest`, as
  `repository`, `tag` and `digest` values, or as a mutate `images` entry
  with `tag` and `digest`. A `tag` value may be quoted: trust-manager's
  default package image has the tag `20250419.2`, which YAML reads as a
  number otherwise. `renovate.json` keeps only `**/node_modules/**`
  of the `ignorePaths` that `config:recommended` sets, because those skip
  `tests/` and with it the image pins of the Chainsaw tests. Package rules put what has to change together
  into one pull request: an operator class's chart and images, so that a
  chart's CRDs never run with another operator version, together with the
  Keycloak image and Strimzi's Kafka client image (EX-5a), and the same
  for the cert-manager and trust-manager classes of `cert-manager-mutate`,
  so that one pull request moves both cert-manager pins; kind and its
  node image; podinfo's chart and image; `@pulumi/kubernetes` and its
  plugin.

  Three values follow another pin, and the pull request that changes that
  pin has to change them: the redis tag follows Argo CD's manifest (EX-7),
  so Renovate updates only the digest of the pinned tag, the Kafka
  version of the `kafka` recipe follows the versions Strimzi supports, and
  the jsonnet sources of kube-prometheus-stack in `chart-vs-kapitan` follow
  the chart (EX-13a). CI fails when one no longer fits.

  The Kapitan side of `chart-vs-kapitan` follows its chart the same way
  for metrics-server and kube-prometheus-stack. Their image tags, and the
  version and sha256 of the Prometheus Operator CRDs that `check`
  downloads, are the ones the chart ships, and the pull request that moves
  the chart sets them. Renovate proposes neither a tag nor a CRD version
  for them. It still updates the digest of a pinned image tag. Grouping
  them with the chart would not keep the two sides equal, because Renovate
  moves each image to its newest tag. On 2026-10-22 the former group
  `kube-prometheus-stack` held Prometheus v3.15.1 alone, while chart
  92.11.0 ships v3.15.0. EX-13 fails when an image tag of metrics-server
  or cert-manager, or the content of cert-manager's CRDs, differs from the
  chart's. The comparison of kube-prometheus-stack does not look at
  versions (OQ-6).

  cert-manager releases its chart, the CRDs that `check` downloads and the
  controller, cainjector, webhook and ACME solver images under one
  version, so the newest tag of each image is the chart's. Renovate moves
  these six pins in the group `chart-vs-kapitan cert-manager` and creates
  the group's branch only once all six have an update
  (`minimumGroupSize: 6`). The CRDs are a GitHub release asset and wait
  three days (EX-3b). The chart and the images on quay.io do not, so for
  three days the group has five updates and no branch. Digest updates of
  the chart and the images stay outside the group, and a rebuilt tag
  still gets its own pull request.

  A newer cert-manager release within those three days leaves the group
  with the chart and images of the newer release and the CRDs of the
  older one. EX-13 fails on this when the CRDs of the two releases differ.
  When they are equal and the pull request is merged as it is, the CRD pin
  stays one release behind until the next release, because one update
  stays below the group size.

  Kapitan and Python packages are pinned by version through uv or with
  `==` in the scripts' `uv run --with` and `uvx`, which a regex manager
  updates with `datasource=pypi`; npm packages through `package-lock.json`;
  jsonnet libraries through `jsonnetfile.lock.json`, whose entry follows a
  branch and which Renovate's lock file maintenance refreshes with
  `jb update`. `talosctl` is pinned by the sha256 that the Siderolabs
  release lists in `sha256sum.txt`. The `first-platform` workflow template
  pins the registry's reusable workflow by the commit of `main`, for which
  the registry publishes no release tag; Renovate follows `main` with
  `datasource=github-digest`. `gh`, `jq`, `curl`, `openssl`, `python3` and
  `docker` come from the runner image. Kapitan 0.36.3 with the `omegaconf`
  extra MUST be installed with `omegaconf==2.4.0.dev4`: omegaconf 2.4.0
  breaks its OmegaConf backend (kapicorp/kapitan#1621).

  Pulumi's Kubernetes provider plugin is pinned by the `@pulumi/kubernetes`
  version in `same-app/pulumi/package-lock.json` and by version and sha256
  of its linux-amd64 archive in the workflow; `same-app/check` passes the
  sha256 to `pulumi plugin install --checksum`, which fails when the two
  versions differ. `npm ci` runs with `--ignore-scripts`,
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
    back; workflow job `pins`. On 2026-10-22 Renovate 44.171.1 got
    `chart-vs-kapitan` with cert-manager's chart, CRDs and four images at
    v1.21.1 and the metrics-server image at v0.8.0. It opened one branch,
    `renovate/chart-vs-kapitan-cert-manager`, that moves all six to
    v1.21.2, and none for metrics-server and Prometheus v3.15.1. A stale
    digest on cert-manager's webhook tag got a branch of its own, and so
    did the kubernetes generator one release back (#50). `--platform=local`
    stops before the branch worker, which applies `minimumGroupSize`.
    Against a local Gitea with `--dry-run=full`, Renovate would commit the
    group's branch, and skipped it with the CRDs' release age raised to 90
    days, which leaves five updates
  - Since: tbd; checksums by Renovate: #15; operator charts and images: #21;
    every pin by Renovate: #23; `cert-manager-mutate`: #28; `gvisor-ci/run`:
    #33; `chart-vs-kapitan` follows the chart: #50; cert-manager's group in
    `chart-vs-kapitan`: #51

- EX-3a: Every image that an inventory, a Chainsaw test, a script or a
  workflow names MUST be pinned as `tag@sha256:digest`.

  The tag tells the reader which release runs, the digest makes every run
  pull the image CI checked. Renovate updates tag and digest in one pull
  request, and opens a digest-only one when the publisher rebuilds a tag,
  as CloudNativePG does with `postgresql:18.6-system-trixie`. Where the tag
  points to a multi-arch index, the digest is the index's, which
  `crane digest` and Renovate's docker datasource both return.

  Oracle publishes no index for MySQL: `community-server:9.7.3` is a
  linux/amd64 image and the arm64 build has its own tag, `9.7.3-aarch64`.
  The recipe pins the digest of the amd64 image, the one the tag alone
  pulled before.

  The rootfs image of `gvisor-ci/run` stays on Python 3.13, the version
  `run` also uses on the host through `uv run --python 3.13`, so that the
  escape scripts run on the same minor version inside and outside the
  sandbox. A package rule for that file keeps it below 3.14; Renovate
  updates the digest of `3.13-slim` and proposes no `3.14-slim`.

  Three kinds of reference carry no digest. The `ghcr.io/example/*` images
  in `same-app` and `config-tools` are placeholders that no registry holds;
  Renovate skips them. The documents in `apiserver-dry-run/manifests/` only
  reach kubeconform and an API server without a kubelet, so nothing pulls
  their images. Images that a chart or a release
  manifest names itself keep the publisher's reference: Strimzi's chart
  maps each Kafka version to a tag in `STRIMZI_KAFKA_IMAGES`. The chart
  digest or the manifest's sha256 fixes such a reference, not the image
  behind it.

  - Test: `manual:` `git grep -nE 'image(_name)?(: |=)[a-z0-9.-]+\.[a-z]+/' -- '**/inventory/**' '*/tests/**' | grep -v @sha256:`
    lists the placeholders only; `renovate --platform=local --dry-run=lookup`
    reports every image with its current digest, and with the digest of
    `gvisor-ci/run` set back proposes the current `3.13-slim` digest and
    no 3.14
  - Since: #32; `gvisor-ci/run`: #33; `chart-vs-kapitan`: #50

- EX-3b: Renovate MUST propose a version only once it has been published
  for three days.

  `minimumReleaseAge` counts from the release timestamp the datasource
  reports, and `internalChecksFilter: strict` holds back branch and pull
  request until then. A version without a timestamp is held
  (`minimumReleaseAgeBehaviour: timestamp-required`). npm, PyPI, GitHub
  releases and their assets report the publish time; `github-tags` does
  where the tag has a GitHub release, as argo-cd's and kubeconform's have.
  `github-digest` reports the date of the commit that `main` points to,
  which for the registry's merge commits is the merge.

  Registries other than Docker Hub list tags without a date, so images and
  OCI charts from ghcr.io, quay.io, registry.k8s.io, mirror.gcr.io and
  Oracle's registry cannot be held and go through at once
  (`timestamp-optional`), as do the generator pins of the org preset. Docker
  Hub dates a tag by its last push, which a rebuild only moves later.

  cert-manager's chart and images in `chart-vs-kapitan` wait for its CRDs.
  Their group (EX-3) gets a branch only once the CRDs' GitHub release is
  three days old.

  Renovate's `terraform-provider` datasource dates a version on
  registry.opentofu.org by the `published` field of api.opentofu.org, which
  is the date of the tagged commit. HashiCorp tagged kubernetes provider
  3.4.0 on 2026-10-16 and published it on 2026-10-19; the OpenTofu registry
  added its build at 21:01 UTC that day, and #27 updated it the next
  morning. A package rule therefore looks these providers up through the
  custom datasource `opentofu-provider`, which reads the registry's
  metadata in opentofu/registry (`providers/<n>/<namespace>/<name>.json`)
  and takes the `discovered` field, the time the registry added the
  version. Versions added before 2026-04-21 carry that date instead, which
  is later than their release. `registryUrls: []` makes the custom
  datasource use its own URL; the lock file update takes the hashes from
  the registry named in `.terraform.lock.hcl`, as before.

  `node-version` dates a release by day, at midnight UTC, so Node.js waits
  four days.

  - Test: `manual:` `renovate --platform=local --dry-run=lookup` with the
    kubernetes provider set back to 3.3.0 in `main.tf` and the lock file.
    On 2026-10-20 Renovate 44.171.1 dated 3.4.0 2026-10-19T21:01:52Z and
    held it, and held rabbitmq 4.4.0 (Docker Hub), oras 1.3.5, uv 0.13.3
    and cdk8s 2.70.112; with the previous configuration it dated 3.4.0
    2026-10-16T16:43:56Z and proposed it (partial: the lookup does not
    update the lock file; the next provider pull request does)
  - Since: #35

- EX-4: Examples MUST NOT use `kapitan compile --fetch` unless the fetched
  generators were verified before.

  `--fetch` checks neither the index nor the attestations. The scripts verify
  the index signature and each artifact's attestation with the registry's
  release workflow identity, pull by digest with `oras` and compile without
  `--fetch`.

  `chart-vs-kapitan/check`, `same-app/check` and `config-tools/check` keep
  the generators they pulled in `kapitan/lib/`, each with the reference it
  was pulled by. When a pin in `kapitan/inventory/classes/` names another
  digest, or a generator in `kapitan/lib/` has no reference, they verify
  and pull that generator again.

  - Test: `manual:` `grep -rn -- --fetch */check`; `manual:`
    `chart-vs-kapitan/check` and `same-app/check` pull the kubernetes
    generator again after its pin in `common.yml` changed, and not while
    the pin is unchanged; `same-app/check` also pulls it again over a
    `kapitan/lib/kubernetes` without a reference
  - Since: tbd; `chart-vs-kapitan` pulls again on a changed pin: #50;
    `same-app` and `config-tools`: #51

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

  Images come from the project that builds the software, pinned by tag and
  digest in the class (EX-3a). Secrets a recipe generates, such as the Valkey password, are
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
  - Since: #8, #20; images by tag and digest: #32

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
  install`. The recipe classes pin the PostgreSQL and Keycloak images that
  the operators start by tag and digest (EX-3a); Strimzi starts the Kafka
  image its chart maps to the recipe's Kafka `version`.

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

  Decided in #22 (OQ-4): the operator stays installed by `check`
  rather than compiled with the recipe. A Kapitan `https` dependency with a
  `copy` entry could bring the manifest into the target, but fetches it
  without a checksum.

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
  - Since: #21; OQ-4 decided: #22

- EX-5b: The `mysql` recipe MUST stay on MySQL's 9.7 LTS release line.

  From 26.7 on, Oracle numbers the MySQL Innovation releases by calendar,
  YY.M.P; 9.7 is the LTS release. Readers copy a recipe into their own
  projects, so it follows the LTS line, which takes bug and security fixes,
  rather than the Innovation releases, which add features. A package rule
  allows only versions below 10 for
  `container-registry.oracle.com/mysql/community-server`: Renovate proposes
  9.7 patch releases and new digests, no 26.x. Moving the recipe to the
  next LTS line changes this requirement and the rule together.

  - Test: `renovate --platform=local --dry-run=lookup` with the pin one
    patch release back proposes the next 9.7 release, not 26.x
  - Since: #32

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
  it, and the watcher stopped a healthy install on that in CI. Two polls
  did not always cover that wait; EX-7 therefore starts those pods only
  once the Secret exists. `recipes/check` polls the pods of all namespaces every
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
  - Since: #8, #10, #13, #16, #17, #20, #31; operators from the compiled target: #21

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
  the Git server and the tool as for an operator.

  `check` applies Argo CD's manifest in two steps: the objects labelled
  `app.kubernetes.io/name=argocd-redis` first, the whole manifest once the
  Secret `argocd-redis` exists. The redis pod's init container
  `secret-init` creates that Secret; Argo CD's server, repo server and
  application controller cannot start without it. Applied in one step,
  every Argo CD pod pulls the Argo CD image at once, `secret-init` waits
  behind the others, and the three wait with `CreateContainerConfigError`,
  which EX-6 counts as broken. That stopped a healthy install in the first
  attempt of the `examples` run on main after #35, and in both local runs
  with `secret-init` delayed by 20 and 60 seconds. Exempting that wait
  from the watcher was tried and is not enough: the server then starts
  late, and dex exits with `server.secretkey is missing` until it runs,
  which the watcher counts as broken as well. A `secret-init` that fails
  or cannot pull its image still makes the redis pod broken. The install
  seconds the guide quotes count from the first step.

  `check` replaces the redis image of Argo CD's manifest, `public.ecr.aws/docker/library/redis`,
  with `REDIS_IMAGE`, the same tag on `mirror.gcr.io/library/redis` pinned
  by digest (for 8.2.3-alpine identical on ECR Public, Docker Hub and the
  mirror, checked 2026-10-19), and fails when the manifest names another
  tag: ECR Public answered anonymous pulls from GitHub runners with "429 Too Many Requests" in three of four runs, and the
  manifest pulls redis with `imagePullPolicy: Always`, so a pull before the
  install would not help. The Argo CD Application syncs automatically with
  `prune` and `selfHeal`; the Flux objects keep the flux generator's
  defaults plus `prune: true`. `check` prints the numbers the guide quotes:
  the CRDs in the release manifest, the tool's pods and images, the seconds
  from applying the manifest until its Deployments are available, the
  seconds from creating the Application or Kustomization until the app's
  Deployment is available, and the memory working set of the tool's pods
  after the check, read from the kubelet summary API.

  - Test: `examples` workflow, job `argocd-vs-flux` per tool; the install
    order by hand, with `secret-init` delayed by 60 seconds (passes) or
    exiting non-zero (stops the check on the redis pod)
  - Since: #14, #16; redis first: #37

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

Decided in #22 (OQ-3): the digest pin is the chart's only check,
because it makes the render reproducible. Renovate updates the chart's
version and digest and the tag and digest of `pin-image` in one pull
request (EX-3).

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

  The mutations are `pin-image` (`images`, the podinfo image by tag and
  digest),
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
  - Since: #19; OQ-3 decided: #22

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
  Install pins, the install order, the redis image rewrite and the failure
  output are those of EX-6 and EX-7.

  - Test: `helm-mutate/tests/<tool>/chainsaw-test.yaml`; `examples`
    workflow, job `helm-mutate` per tool
  - Since: #19

## cert-manager and trust-manager charts patched with mutate

`cert-manager-mutate/` backs the kadet-hub.org blog post that fixes two
requests against the cert-manager project's Helm charts with mutate
instead of a chart value. cert-manager/cert-manager#6071 asks for init
containers on the controller Deployment; a maintainer declined the value
and pointed to a Helm post-rendering step. cert-manager/trust-manager#778
asks for the webhook certificate to come from an issuer managed outside
the chart; the chart always renders a selfSigned Issuer `trust-manager`
and points the webhook's Certificate `trust-manager` at it. Neither
cert-manager v1.21.2 nor trust-manager v0.25.0, the latest releases on
2026-10-20, has a value for it; cert-manager's chart takes
`extraContainers` only.

The project has the layout of `helm-mutate`. Classes `cert-manager` and
`trust-manager` pin each chart by version and OCI digest and render it
with the `helm` input. Both charts' values take tag and digest for every
image, so no mutation pins an image. Target `helm` renders both charts
alone and is the target `check` fetches with (EX-4); targets
`cert-manager` and `trust-manager` add one mutate entry each on the
chart's `output_path` with `output_type: plain`. trust-manager is
rendered into `cert-manager`, its default trust namespace.

`internal-ca.yaml` is the issuer managed outside the chart: a selfSigned
ClusterIssuer issues the CA Certificate `internal-ca` into
`cert-manager`, where cert-manager reads the Secrets of ClusterIssuers,
and the CA ClusterIssuer `internal-ca` signs with it. `bundle.yaml`
distributes that CA with a trust-manager Bundle, from the Secret in the
trust namespace. approver-policy is not installed, so
`app.webhook.tls.approverPolicy.enabled` stays false and the chart
renders no CertificateRequestPolicy; with it, the policy's `issuerRef`
selector would need the same change.

- EX-11: `cert-manager-mutate/check` MUST fail unless the compiled
  Deployment `cert-manager` carries the init container and the other two
  Deployments none, the compiled trust-manager output holds no Issuer and
  its Certificate `trust-manager` names the ClusterIssuer `internal-ca`,
  and, deployed to a new kind cluster, the controller pod is Ready with
  the init container terminated with exit code 0, the Certificate is
  Ready, no Issuer `trust-manager` exists, the webhook certificate
  verifies against the CA of `internal-ca`, that CA is the `ca.crt` of
  the webhook's Secret, the webhook's caBundle and the Bundle's
  ConfigMap, and the Bundle is Synced.

  The mutations are `init-containers` (`json6902` `add` of
  `/spec/template/spec/initContainers` on `apps/v1` Deployment
  `cert-manager`: a busybox container, pinned by tag and digest, that
  echoes one line), `no-selfsigned-issuer` (`delete` of
  `cert-manager.io/v1` Issuer `trust-manager`) and `webhook-issuer`
  (`merge` of `spec.issuerRef` on `cert-manager.io/v1` Certificate
  `trust-manager`). `add` creates the list because the chart renders
  none; on an existing list it would replace it. The pod sets
  `runAsNonRoot` and busybox runs as root, so the init container sets
  `runAsUser`.

  The Bundle passes trust-manager's webhook, whose caBundle cainjector
  copies from the webhook's Secret (`cert-manager.io/inject-ca-from-secret`),
  so its creation shows that the API server trusts the certificate
  `internal-ca` issued. `check` applies cert-manager's chart server-side,
  because three of its CRDs exceed the annotation size of a client-side
  apply, and repeats every apply as in EX-6, because cert-manager's
  webhook admits the Certificates and trust-manager's the Bundle. Broken pods and a
  timed-out wait are reported as in EX-6, and the diff between the two
  renders is printed as in EX-9. kubeconform is not run: mutate's schemas
  cover five core kinds, and the API server validates every object of the
  output on apply.

  - Test: `cert-manager-mutate/tests/chainsaw-test.yaml`; `examples`
    workflow, job `cert-manager-mutate`
  - Since: #28

## Charts rebuilt as Kapitan inventories

`chart-vs-kapitan` rebuilds widely used Helm charts as Kapitan inventories
on the omegaconf backend, rendered by kadet-hub generators, to show
what a chart author would maintain instead of templates. The chart side is
`helm template` with the values in `values/<chart>.yaml`; the Kapitan side
is `kapitan/inventory/targets/<chart>.yml`. Parts that are Helm hooks
(cert-manager's startupapicheck) are switched off on the chart side,
because Kapitan has no hooks.

Names, list order and RBAC layout differ by design: the generator names
objects by its own convention, puts one ClusterRole on each component and
cannot use colons in names, which double as label values. The check
therefore compares objects after the API server has defaulted them, with
names, labels, selectors and port order normalized, and compares RBAC by
what it grants. Two differences are normalized and named. The generator
keeps a webhook out of its own namespace, which the chart does not. The
Kapitan side names its images as `tag@sha256:digest` (EX-3a), including
the ACME solver image that cert-manager's controller takes as an
argument, while the chart names the tag alone. This digest pinning is
intended. The check strips the digest from container images and their
arguments on the Kapitan side only, so a tag that differs from the
chart's still fails.

- EX-13: `chart-vs-kapitan/check <chart>` MUST fail unless, for
  metrics-server and cert-manager,
  the objects of both sides outside RBAC are equal after a server-side dry
  run and the normalization above, `kubectl auth can-i --list` is equal for
  every ServiceAccount of the chart and for a user bound only to the
  built-in `view` ClusterRole, and the Kapitan side, installed on its own
  kind cluster, does what the chart does: `kubectl top nodes` answers for
  metrics-server, a self-signed ClusterIssuer issues a Certificate for
  cert-manager.

  Each side is installed on a fresh cluster, so neither sees runtime state
  the other left behind, such as cert-manager's webhook CA Secret. An
  empty normalized object list fails the check, so a broken normalization
  cannot pass as equality. The check prints the template and values lines
  the chart maintains and the inventory lines the Kapitan side needs.

  - Test: `examples` workflow, job `chart-vs-kapitan`; `manual:` with the
    metrics-server image set to v0.8.0 and its digest, or cert-manager's
    ACME solver image to v1.21.1 and its digest, the object diff fails on
    the tag
  - Since: #44; digest pinning: #50

kube-prometheus-stack 92.11.0 cannot be compared object by object. Its
Kapitan side renders the operator, kube-state-metrics, node-exporter and
Grafana with the `kubernetes` generator and Prometheus, Alertmanager and
the 13 ServiceMonitors with the `prometheus-operator` generator, under the
generators' names wherever nothing selects an object by its name. `rbac:
true` on Prometheus grants the generator's fixed rule set, which adds `get`
on ConfigMaps and leaves out `/metrics/cadvisor`. For this chart `check`
prints the objects of both sides by kind and compares what they do.

The Kapitan side carries over every setting of the chart that changes what
runs, except these:

- Alertmanager runs under the namespace's `default` ServiceAccount; the
  chart creates one for it, which it does not use to call the API.
- Prometheus and Alertmanager have no preferred pod anti-affinity, which
  spreads replicas the chart does not run (it runs one of each).
- Grafana declares no container ports for gossip and profiling and no
  `POD_IP`, which Grafana uses only with a high-availability setup the
  chart does not configure, and keeps its search index in its data
  directory, where the chart mounts another emptyDir.

The rest of what it leaves out equals the defaults of the operator,
kube-state-metrics, node-exporter, Grafana's image and the sidecar, such
as the operator's `--kubelet-endpoints` and `--web.listen-address`, and
Grafana's `GF_PATHS_*` and log mode.

- EX-13a: `chart-vs-kapitan/check kube-prometheus-stack` MUST fail unless
  both sides, each installed on its own kind cluster, report the same
  scrape jobs with the same health, the same alerting and recording rule
  names, Alertmanager ready, and Grafana healthy with the same datasources
  and dashboard titles.

  `check` reads Prometheus' `/api/v1/targets` and `/api/v1/rules` and
  Alertmanager's `/-/ready` through the API server's service proxy, and
  Grafana's `/api/health`, `/api/datasources` and `/api/search` through a
  port-forward, with the admin password from the Secret that Grafana's
  Deployment names. A target reports health `unknown` until its first
  scrape. `check` polls every 30 seconds, longer than the scrape interval,
  until no target is `unknown` and two rounds agree, and fails after ten
  minutes. An empty set of targets, rules, datasources or dashboards fails
  the check.

  Health is compared, not required to be `up`: kind binds the metrics of
  kube-controller-manager, kube-scheduler, etcd and kube-proxy to
  localhost, so these targets are down on both sides. No other difference
  needs an allowlist.

  - Test: `examples` workflow, job `chart-vs-kapitan`
    (`kube-prometheus-stack`); `manual:` with one ServiceMonitor and one
    rule group dropped from the Kapitan side, the check fails on the
    missing job and rules
  - Since: #47

Prometheus names a scrape job after the Service it scrapes, unless the
ServiceMonitor's `jobLabel` names a label of that Service. The chart's
rules select the jobs by these names, `job="kube-prometheus-stack-operator"`
for example, so the Kapitan side names the scraped Services like the chart,
from the parameter `release`. Prometheus and Alertmanager run in pods the
operator creates, and the control-plane Services select pods kind runs.
The `kubernetes` generator renders Services only for its own components,
so these seven Services are `manifests` entries.

The rules and dashboards are not copied from the chart.
`kapitan/components/kube-prometheus-stack.jsonnet` builds them with
Kapitan's `jsonnet` input from the sources that the chart's
`hack/sync_prometheus_rules.py` and `hack/sync_grafana_dashboards.py` read
at the tag `kube-prometheus-stack-92.11.0`: kube-prometheus at
`f81c076ab8f542c457840cd4c62656b8d6b4f43a`, the etcd mixin at
`479c194f3f5754f039a74c396f3e70f6419edf8e` and the chart's own
`files/dashboards/k8s-coredns.json`. The kubernetes-mixin commit the
scripts name is used for the Windows rules and dashboards only, which the
chart leaves out at its default values. The jsonnet applies the settings
and text edits of the two scripts at the chart's default values: job
names, a space between `by` or `on` and the parenthesis, trailing
whitespace, the etcd runbook URLs, and the dashboards' timezone, editable
flag, interval and `cluster` variable.

Rendered side by side, 34 of the chart's 35 rule groups and all 29
dashboards are equal. The chart's group `k8s.rules.container_resource`
comes from a template that the sync at these commits no longer writes. The
sources split it into `k8s.rules.container_cpu_limits`,
`k8s.rules.container_cpu_requests`, `k8s.rules.container_memory_limits` and
`k8s.rules.container_memory_requests`. The chart ships these four as well
but switches them off, because its values lack the keys that enable them.
Both hold the same eight recording rules, with expressions that differ in
whitespace only, so the rule names are equal and the Kapitan side has 38
PrometheusRules to the chart's 35.

`kapitan/jsonnetfile.json` pins the three sources by commit, and pins the
libraries that kube-prometheus pulls at a branch, such as grafonnet,
mixin-utils and the Perses mixins, at the commits of kube-prometheus' own
lock file, which the chart's sync installs from. Lock file maintenance,
`jb update`, therefore leaves `jsonnetfile.lock.json` as it is. The pull
request that moves the chart to a new version has to move the sources to
the commits its sync scripts name. `check` vendors them with `jb install`
into `kapitan/vendor/` and compiles with go-jsonnet, which takes seconds
where the C++ implementation takes over a minute.

The chart side sets `prometheusOperator.admissionWebhooks.enabled=false`
and `grafana.testFramework.enabled=false`, which are Helm hooks, and
`prometheusOperator.tls.enabled=false`. Without the webhooks' certificate
Job nothing creates the Secret `kube-prometheus-stack-admission`, which the
operator mounts while TLS is on. Its pod then stays in `ContainerCreating`
with `MountVolume.SetUp failed for volume "tls-secret"`, seen on kind with
chart 92.11.0.

The chart generates Grafana's admin password into a Secret. The Kapitan
side commits none: `admin-password` is the Kapitan ref
`?{base64:grafana/admin-password||random:str:40}`, which the first compile
creates in `check`'s temporary refs path and the second, with `--reveal`,
writes into the Secret. The base64 backend encrypts nothing, as in the
recipes (EX-5).

## Open questions

- OQ-1: Python interpreters are downloaded by uv and package versions come
  from PyPI without a hash pin outside `first-platform/uv.lock`. Is a uv lock
  per example worth the extra files?
- OQ-2: `apiserver-dry-run/check` validates against the Kubernetes schemas
  from the default kubeconform location, which tracks the `master` branch of
  yannh/kubernetes-json-schema. The schema version it names,
  `-kubernetes-version 1.37.1`, is set by hand.
- OQ-5: `apiserver-dry-run/crds/` holds the Gateway API v1.6.3 CRDs as a
  committed copy of the release asset, which Renovate cannot replace.
  Should `check` download them by version and sha256 instead, although the
  post's workflow template reads them from the folder?
- OQ-6: `chart-vs-kapitan/check kube-prometheus-stack` compares what both
  sides do, not their versions. A chart pull request that leaves an image
  tag or the CRDs of the Kapitan side behind passes CI. Should `check` also
  compare the image tags of both sides?

## Inventory

| Path | Content |
|---|---|
| `.github/workflows/examples.yml` | One job per example, tool versions, sha256 and images in `env`; job `pins` (EX-3) |
| `renovate.json` | Org preset for generator pins; regex managers for `# renovate:` comments, inventory charts and images, `==` pins in scripts; package rules that group pins, cert-manager's in `chart-vs-kapitan` included, and leave the rest of its Kapitan side to the chart (EX-3), keep MySQL on 9.7 (EX-5b) and the Python image of `gvisor-ci/run` on 3.13 (EX-3a); release age and the custom datasource `opentofu-provider` (EX-3b) |
| `apiserver-dry-run/.github/workflows/dry-run.yml`, `first-platform/.github/workflows/compile.yml` | Templates shown in the posts; GitHub does not run them here |
| `talos-machine-config/` | One Kapitan project, target `lab` with three Talos nodes; `check` verifies the generator, fills the refs, compiles and runs `talosctl validate` |
| `helm-vs-terraform/providers/.terraform.lock.hcl`, `helm-vs-terraform/terraform-only/.terraform.lock.hcl` | Provider hashes; the first is copied into the compiled root module |
| `recipes/` | One Kapitan project; `check <recipe>` verifies the generators, compiles, deploys to kind and runs the recipe's check |
| `recipes/inventory/classes/recipes/operators/` | One class per operator with a Helm chart: chart pin, `helm` and `mutate` entries, image pins (EX-5a) |
| `recipes/inventory/targets/charts.yml` | Every operator class and no generator, for `check` to fetch the charts (EX-4, EX-5a) |
| `argocd-vs-flux/` | One Kapitan project (targets `web`, `argocd`, `flux`), the Gitea manifest and a Chainsaw test per tool; `check <argocd\|flux>` |
| `helm-mutate/` | One Kapitan project (targets `helm`, `podinfo`, `argocd`, `flux`), the podinfo chart pinned in `inventory/classes/podinfo.yml`, the mutations in `inventory/targets/podinfo.yml`, a Chainsaw test per tool; `check <kubectl\|argocd\|flux>` |
| `chart-vs-kapitan/` | One Kapitan project on the omegaconf backend, one target per chart, chart values in `values/`, CRDs and jsonnet libraries fetched by `check` into `kapitan/vendor/`; `check <chart>` (EX-13, EX-13a) |
| `chart-vs-kapitan/kapitan/components/kube-prometheus-stack.jsonnet`, `chart-vs-kapitan/kapitan/jsonnetfile.json`, `chart-vs-kapitan/kapitan/jsonnetfile.lock.json` | Rules and dashboards of kube-prometheus-stack and the pins of their sources (EX-13a) |
| `cert-manager-mutate/` | One Kapitan project (targets `helm`, `cert-manager`, `trust-manager`), the charts pinned in `inventory/classes/`, the mutations in the two targets, `internal-ca.yaml`, `bundle.yaml`, one Chainsaw test; `check` |

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
