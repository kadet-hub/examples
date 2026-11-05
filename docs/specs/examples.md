# Examples

Status: Draft
Code: `*/check`, `gvisor-ci/run`, `apiserver-dry-run/dry-run`, `argocd-vs-flux/`, `helm-mutate/`, `cert-manager-mutate/`, `first-platform/inventory/classes/shop.yml`, `helm-vs-terraform/inventory/classes/uploads.yml`, `kubevirt-csi/`, `open-webui-searxng/`, `platform-baseline/`, `immich-cnpg/`, `pihole-powerdns/`, `helmfile-vs-kapitan/`, `timoni-vs-kapitan/`, `kcl-vs-kapitan/`, `argocd-cmp/`, `.github/workflows/examples.yml`, `.github/workflows/request-review.yml`, `.github/workflows/compile-diff.yml`, `.github/workflows/compile-diff-comment.yml`, `renovate.json`
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
  base64 backend and compiles with `--reveal`. Without it the configs hold
  ref tokens, which are not valid base64, and `talosctl validate` rejects
  them. It also rejects a cluster CA document that is not PEM. A base64
  value that is not a certificate passes elsewhere in the main config
  document (checked with talosctl v1.14.5), so validation does not prove
  the certificates are real. Neither the refs nor the compiled configs are
  committed.

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
  `first-platform` and `helm-vs-terraform` unless EX-12 holds,
  `kubevirt-csi` unless EX-14 and EX-14a hold, `open-webui-searxng`
  unless EX-17 holds, `platform-baseline` unless EX-18 and EX-18a hold,
  `immich-cnpg` unless EX-19 holds, `pihole-powerdns` unless EX-20 holds,
  `helmfile-vs-kapitan` unless EX-21 holds, `timoni-vs-kapitan` unless
  EX-22 to EX-22b hold, `kcl-vs-kapitan` unless EX-23 to EX-23b hold,
  `argocd-cmp` unless EX-24 holds.

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

- EX-1b: The `gvisor-ci` job MUST print the runner's swap with
  `swapon --show` before anything runs under `runsc`.

  A memory limit under runsc is not enforced on a host with swap
  (google/gvisor#15756). The rootless run sets none, so the runner's memory
  and swap are the cap, and the log shows how much that is.

  - Test: manual: the `Show swap` step in the job log
  - Since: #108

- EX-2: CI MUST run every example's script weekly, in addition to pull
  requests and pushes to `main`.

  - Test: `examples` workflow, `schedule` trigger
  - Since: tbd

- EX-16: The `ci` job of the `examples` workflow MUST fail unless every
  other job of the run succeeded or was skipped.

  It runs on every trigger with `if: always()` and is the one check the
  `main` ruleset requires, so the ruleset need not change when a job is
  added. A job left out of its `needs` is not gated.

  - Test: `examples` workflow, job `ci`; `manual:` it failed on #88 while
    `advisories` failed
  - Since: #88

- EX-12: CI MUST deploy every workload that an example renders to run to
  a new kind cluster and fail unless the workload becomes ready.

  kubeconform and an API server accept manifests that the kubelet cannot
  run, such as a readiness probe on a port the app does not listen on.
  `argocd-vs-flux`, `helm-mutate`, `cert-manager-mutate`,
  `kubevirt-csi`, `open-webui-searxng`, `platform-baseline`,
  `immich-cnpg`, `pihole-powerdns`, `helmfile-vs-kapitan` and `argocd-cmp`
  deploy their workloads under EX-7, EX-10, EX-11, EX-14, EX-17, EX-18,
  EX-19, EX-20, EX-21 and EX-24.
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

  The other examples have no workload of their own to deploy. `same-app`,
  `config-tools`, `timoni-vs-kapitan` and `kcl-vs-kapitan` render the
  placeholder images `ghcr.io/example/*`
  (EX-3a), `apiserver-dry-run` sends its documents to an API server
  without a kubelet, `talos-machine-config` renders node configs, and
  `verify-oci` and `gvisor-ci` render no manifests. `bitnami` renders a
  CloudNativePG Cluster with the name, namespace, image, instances,
  storage and bootstrap that the `postgresql` recipe had before it moved
  to kadet-hub/recipes (EX-5).

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
    `helm-vs-terraform`; the other deploys as in EX-7, EX-10 and
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
    Kubernetes plugin, etcd, tk, jb, Timoni, KCL, kind, chainsaw, talosctl,
    tofu and gVisor are GitHub release assets, and so are the install manifest of
    Flux and the CRDs of cert-manager and Prometheus Operator in
    `chart-vs-kapitan`, and the install manifests of Kyverno, the
    Prometheus Operator, External Secrets and the Grafana Operator and the
    velero CLI in `platform-baseline`. In `kubevirt-csi` the
    operator manifests of KubeVirt and CDI, virtctl and the k3s binary are
    release assets too. The k3s pin sits in the cloud-init script of
    `kubevirt-csi/inventory/targets/infra.yml`, which the comment manager
    reads as well. Their `# renovate:` comment names
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
    the image of its sandbox rootfs, `platform-baseline/check` the Velero
    server and AWS plugin images, `timoni-vs-kapitan/check` the registry
    image of EX-22.
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
  recipes in the fetch inventories (`**/fetch/**/*.yml`) through the org
  preset as well, which reads them since kadet-hub/renovate-config#21;
  charts by version and the digest of their OCI artifact (podinfo in
  `helm-mutate`, cert-manager and trust-manager in `cert-manager-mutate`,
  podinfo and Valkey in the classes and in `helmfile/helmfile.yaml` of
  `helmfile-vs-kapitan`, whose digest pins Renovate's own helmfile manager
  skips as `unsupported-chart-type`); images wherever an `image:` or
  `image_name:` key or an `-image=` argument names one, by tag or by
  `tag@sha256:digest`, as
  `repository`, `tag` and `digest` values, or as a mutate `images` entry
  with `tag` and `digest`. A `tag` value may be quoted: trust-manager's
  default package image has the tag `20250419.2`, which YAML reads as a
  number otherwise. `renovate.json` keeps only `**/node_modules/**`
  of the `ignorePaths` that `config:recommended` sets, because those skip
  `tests/` and with it the image pins of the Chainsaw tests. Package rules put what has to change together
  into one pull request: the chart and images of the cert-manager and
  trust-manager classes of `cert-manager-mutate`, so that a chart's CRDs
  never run with another operator version; kind and its
  node image; podinfo's chart and image; `@pulumi/kubernetes` and its
  plugin; the recipes of `immich-cnpg` and `pihole-powerdns`, which pin
  their includes, and those must stay at the digests the index lists
  (EX-19, EX-20); `open-webui` and `searxng` of `open-webui-searxng`,
  which both include valkey (EX-17); the velero CLI and the
  server image `platform-baseline/check` installs with it (EX-18); the
  charts of both sides of `helmfile-vs-kapitan`, outside the podinfo group
  (EX-21).

  Two values follow another pin, and the pull request that changes that
  pin has to change them: the redis tag follows Argo CD's manifest (EX-7),
  so Renovate updates only the digest of the pinned tag, and
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

  Two pins are updated by hand, because Renovate has no manager for
  them: the Kubernetes API schemas that `timoni mod vendor k8s` wrote into
  the Timoni module of `timoni-vs-kapitan` (EX-22), and the `k8s` module
  in `kcl-vs-kapitan/kcl/kcl.mod` with its checksum in `kcl.mod.lock`
  (EX-23).

  Kapitan and Python packages are pinned by version through uv or with
  `==` in the scripts' `uv run --with` and `uvx`, which a regex manager
  updates with `datasource=pypi`; npm packages through `package-lock.json`;
  jsonnet libraries through `jsonnetfile.lock.json`, whose entry follows a
  branch and which Renovate's lock file maintenance (EX-3d) refreshes with
  `jb update`. `talosctl` is pinned by the sha256 that the Siderolabs
  release lists in `sha256sum.txt`. The `first-platform` workflow template
  pins the registry's reusable workflow by the commit of `main`, for which
  the registry publishes no release tag; Renovate follows `main` with
  `datasource=github-digest`. `gh`, `jq`, `curl`, `openssl`, `python3` and
  `docker` come from the runner image. Kapitan 0.36.3 with the `omegaconf`
  extra MUST be installed with `omegaconf==2.4.0.dev4`: omegaconf 2.4.0
  breaks its OmegaConf backend (kapicorp/kapitan#1621).

  Kapitan 0.36.3 requires `cryptography<49`. `first-platform/pyproject.toml`
  lifts that to `cryptography>=50.0.0` with uv's `override-dependencies`,
  for GHSA-g6cj-pr64-35w5, GHSA-jwv3-5hgf-82ww and GHSA-m2h6-j472-rp4c, as
  the registry's gate does (registry GI-16). The override goes once a
  Kapitan release allows 50 (kapicorp/kapitan#1632). Kapitan uses
  cryptography only for the key pairs of its ref functions. A reader who
  copies `first-platform` copies the override with it. The scripts'
  `uv run --with kapitan==0.36.3` resolve without it and stay below 49.

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
    `chart-vs-kapitan`: #51; kafka moved: #77; keycloak moved: #81;
    cryptography override: #86; recipes in a fetch inventory: #132;
    recipe pins through the org preset: #154;
    `platform-baseline`: #135; `helmfile-vs-kapitan`: #140

- EX-3h: Renovate MUST merge its own pull request once every check on it
  passed, unless it is a major update or a digest update of a GitHub Action.

  Renovate merges without GitHub's auto-merge (`platformAutomerge: false`),
  so it waits for every check, including `advisories`. The `main` ruleset
  asks for no approval, so no bypass is needed. A digest update of an
  action under an unchanged version is a moved tag, the pattern of a
  hijacked action. The rule also covers the generator pins that the
  kadet-hub preset leaves unmerged for consumers.

  - Test: manual: `renovate.json` `automerge` rules
  - Since: #107

- EX-3a: Every image that an inventory, a Chainsaw test, a script or a
  workflow names MUST be pinned as `tag@sha256:digest`.

  The tag tells the reader which release runs, the digest makes every run
  pull the image CI checked. Renovate updates tag and digest in one pull
  request, and opens a digest-only one when the publisher rebuilds a tag,
  as CloudNativePG does with `postgresql:18.6-system-trixie`. Where the tag
  points to a multi-arch index, the digest is the index's, which
  `crane digest` and Renovate's docker datasource both return.

  The rootfs image of `gvisor-ci/run` stays on Python 3.13, the version
  `run` also uses on the host through `uv run --python 3.13`, so that the
  escape scripts run on the same minor version inside and outside the
  sandbox. A package rule for that file keeps it below 3.14; Renovate
  updates the digest of `3.13-slim` and proposes no `3.14-slim`.

  Three kinds of reference carry no digest. The `ghcr.io/example/*` images
  in `same-app`, `config-tools`, `timoni-vs-kapitan` and `kcl-vs-kapitan`
  are placeholders that no registry holds;
  Renovate skips them. The documents in `apiserver-dry-run/manifests/` only
  reach kubeconform and an API server without a kubelet, so nothing pulls
  their images. Images that a chart or a release
  manifest names itself keep the publisher's reference. The chart
  digest or the manifest's sha256 fixes such a reference, not the image
  behind it.

  - Test: `manual:` `git grep -nE 'image(_name)?(: |=)[a-z0-9.-]+\.[a-z]+/' -- '**/inventory/**' '*/tests/**' | grep -v @sha256:`
    lists the placeholders only; `renovate --platform=local --dry-run=lookup`
    reports every image with its current digest, and with the digest of
    `gvisor-ci/run` set back proposes the current `3.13-slim` digest and
    no 3.14
  - Since: #32; `gvisor-ci/run`: #33; `chart-vs-kapitan`: #50; kafka moved: #77

- EX-3b: Renovate MUST propose a version only once it has been published
  for three days.

  Security fixes (EX-3c), lock file maintenance (EX-3d) and rebuilt tags
  (EX-3e) are exempt.

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

- EX-3c: Renovate MUST propose the fix for a dependency with an open
  Dependabot alert at once, outside any schedule and without a release age.

  `vulnerabilityAlerts` is enabled in `renovate.json`. Renovate's defaults
  for it drop `schedule` and `minimumReleaseAge` and create the pull request
  immediately, with `[SECURITY]` in its title. The alerts come from GitHub's
  dependency graph, which reads `uv.lock` and both `package-lock.json`,
  transitive entries included. A fix that needs a lifted upstream
  constraint, as cryptography in `first-platform` did, gets no pull request
  and needs a person (EX-3).

  - Test: `manual:` the Dependency Dashboard lists the open alerts, and an
    alert with a fixed version gets a `[SECURITY]` pull request within a day
  - Since: #87

- EX-3d: Renovate MUST refresh every lock file once a week.

  `lockFileMaintenance` regenerates `uv.lock`, both `package-lock.json`,
  both `jsonnetfile.lock.json` and the `.terraform.lock.hcl` of
  `helm-vs-terraform/terraform-only` in one pull request, on Renovate's
  default schedule (Monday before 4 am UTC).
  Before, only the jsonnet locks were refreshed, and transitive npm and uv
  entries stayed at the version they were first locked at. The maintenance
  takes the newest version each lock allows and no release age applies to
  it: Renovate checks the age of the versions it proposes, not of what the
  package manager resolves.

  - Test: `manual:` the Dependency Dashboard lists "Lock file maintenance"
    with its schedule
  - Since: #87

- EX-3e: Renovate MUST propose a new digest of a pinned tag without a
  release age.

  This covers images and OCI charts (`datasource=docker`). A rebuilt tag
  usually carries base image fixes. Registries other than Docker Hub report
  no timestamp and pass at once already (EX-3b); Docker Hub dates the
  rebuild by its push, which held it three days. Digest updates of the
  registry workflow (`github-digest`) and of actions keep the release age.

  - Test: `manual:` `renovate --platform=local --dry-run=lookup` on a pin
    whose Docker Hub tag was rebuilt within three days. On 2026-10-29
    Renovate 44.194.0 got busybox 1.38.0, pushed again 2026-10-28T22:58Z,
    in `kubevirt-csi/tests/pvc.yaml`: the new digest was pending with the
    previous configuration and proposed with this one
  - Since: #87

- EX-4: Examples MUST NOT use `kapitan compile --fetch` unless the fetched
  generators were verified before.

  `--fetch` checks neither the index nor the attestations. The scripts verify
  the index signature and each artifact's attestation with the registry's
  release workflow identity, pull by digest with `oras` and compile without
  `--fetch`.

  `chart-vs-kapitan/check`, `same-app/check`, `config-tools/check`,
  `timoni-vs-kapitan/check` and `kcl-vs-kapitan/check` keep the generators
  they pulled in `kapitan/lib/`, each with the reference it
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

- EX-15: Every pull request MUST request a review from `neat-bot`. That
  review MUST NOT be a condition for merging.

  The `request review` workflow requests `neat-bot` with the repository's
  own token when a pull request is opened, reopened or marked ready. It skips
  drafts, pull requests opened by bots, and pull requests from forks, whose
  token is read-only; on a fork the bot is requested by hand after a look at
  the pull request. `neat-bot` has read access only (terraform-homezone
  GHO-6a), so CODEOWNERS, which requests a code owner only with write access,
  cannot do it, and an approval by `neat-bot` counts toward no approval a
  ruleset requires.

  - Test: manual: on a new pull request the `request review` run succeeds and
    `gh pr view <n> --json reviewRequests` lists `neat-bot`;
    `gh api repos/kadet-hub/examples/collaborators/neat-bot/permission` reports
    `read`
  - Since: #67 (CODEOWNERS), #71, #72 (workflow)

- EX-3g: Renovate MUST regenerate `package-lock.json` with npm below 12.

  npm 12 rejects `npm install --package-lock-only` for a package that
  declares `bundleDependencies` with `EALLOWREMOTE` (npm/cli#9800).
  `cdk8s` declares them, so Renovate's lock update failed on #48 and #57
  and the lock had to be regenerated by hand. `renovate.json` sets
  `constraints.npm` to `<12`, which the Mend Renovate app honours when it
  installs npm. CI runs the npm that Node 26 ships, 11.20.0, so both
  generate the same lock. `allow-remote=all` in `.npmrc` was considered;
  it turns off the npm 12 protection for every package. The constraint
  goes once npm/cli#9800 is fixed.

  - Test: `manual:` the next Renovate pull request that changes
    `config-tools/cdk8s/package-lock.json` carries an updated lock file;
    `npm install --package-lock-only` in `config-tools/cdk8s` fails with
    `EALLOWREMOTE` on npm 12.2.1 and passes on npm 11.20.0
  - Since: #95

- EX-3f: CI MUST fail when osv-scanner reports a published advisory for a
  package in a lock file of the repository.

  The `advisories` job runs `osv-scanner scan source -r .` on every pull
  request and in the weekly run (EX-2). It reads `uv.lock` and both
  `package-lock.json`, dev dependencies included, since a reader copies them
  whole. osv-scanner matches versions; it does not check whether an example
  reaches the vulnerable code. An advisory without a usable fix is accepted
  in `osv-scanner.toml` next to the lock file, with a reason, the date it
  was checked and an `ignoreUntil`. osv-scanner reads no
  `.terraform.lock.hcl`, `jsonnetfile.lock.json`, image or downloaded tool,
  and not the packages the scripts' `uv run --with` resolve at run time.
  osv-scanner itself is a release asset pinned by version and sha256 (EX-3).

  - Test: `examples` workflow, job `advisories`; `manual:` on `main` before
    #86 it exits 1 with the 8 advisories of certifi, cryptography and
    fast-uri, after #86 it exits 0
  - Since: #88

## Recipes

`recipes/` replaced the most-starred Bitnami charts with inventory classes
for kadet-hub generators, each deployed to a kind cluster by CI. All of
them moved to kadet-hub/recipes, which proves them and which kadet-hub.org
shows under `/recipes/`.

- EX-5: Withdrawn. A recipe moved to kadet-hub/recipes once it could be
  proven there, with its project's own chart as source or, where the
  project ships none, designed on the project's image (DEC-10 and DEC-11
  in kadet-hub/recipes), and was then removed here. `valkey`, the replacement for Bitnami's redis
  chart, moved to
  [kadet-hub/recipes `valkey`](https://github.com/kadet-hub/recipes/tree/main/valkey),
  built on valkey-io's chart. Valkey stands in for Redis because Redis 8
  and later are licensed RSALv2, SSPLv1 or AGPLv3, while Valkey stays
  BSD-3-Clause and speaks the same protocol. `mysql` moved to
  [kadet-hub/recipes `mysql`](https://github.com/kadet-hub/recipes/tree/main/mysql),
  designed on Oracle's image, because MySQL ships no chart for a single
  server. `mongodb` moved to
  [kadet-hub/recipes `mongodb`](https://github.com/kadet-hub/recipes/tree/main/mongodb)
  for the same reason, designed on MongoDB Inc's image.
  `external-dns-powerdns` moved to
  [kadet-hub/recipes `external-dns-powerdns`](https://github.com/kadet-hub/recipes/tree/main/external-dns-powerdns),
  rebuilt from external-dns's own chart, with PowerDNS as
  [`powerdns`](https://github.com/kadet-hub/recipes/tree/main/powerdns),
  designed on PowerDNS's image. `kafka` moved to
  [kadet-hub/recipes `kafka`](https://github.com/kadet-hub/recipes/tree/main/kafka),
  designed on Strimzi's image, with the Strimzi operator as
  [`strimzi`](https://github.com/kadet-hub/recipes/tree/main/strimzi),
  rebuilt from Strimzi's chart. `postgresql` moved to
  [kadet-hub/recipes `postgresql`](https://github.com/kadet-hub/recipes/tree/main/postgresql),
  rebuilt from CloudNativePG's chart `cluster`, with the CloudNativePG
  operator as
  [`cnpg`](https://github.com/kadet-hub/recipes/tree/main/cnpg),
  rebuilt from the project's chart. `rabbitmq` moved to
  [kadet-hub/recipes `rabbitmq`](https://github.com/kadet-hub/recipes/tree/main/rabbitmq),
  designed on RabbitMQ's image, with the RabbitMQ Cluster Operator as
  [`rabbitmq-cluster-operator`](https://github.com/kadet-hub/recipes/tree/main/rabbitmq-cluster-operator),
  rebuilt from its release manifest. `keycloak` moved to
  [kadet-hub/recipes `keycloak`](https://github.com/kadet-hub/recipes/tree/main/keycloak),
  designed on Keycloak's image, with the Keycloak Operator as
  [`keycloak-operator`](https://github.com/kadet-hub/recipes/tree/main/keycloak-operator),
  rebuilt from the project's chart.

  - Since: #8, #20; images by tag and digest: #32; valkey moved: #66;
    mysql moved: #68; mongodb moved: #70; external-dns-powerdns moved: #74; kafka moved: #77;
    postgresql moved: #78; rabbitmq moved: #79; keycloak moved and withdrawn: #81

- EX-5a: Withdrawn. The operators are prerequisites of the recipes that
  need them in kadet-hub/recipes (DEC-13 there), each a recipe of its own.
  OQ-7, on verifying Keycloak's signatures in the operator class and in
  `recipes/check`, went with them.

  - Since: #21; OQ-4 decided: #22; Keycloak 26.8.1 re-push: #61;
    kafka moved: #77; postgresql moved: #78; rabbitmq moved: #79;
    keycloak moved and withdrawn: #81

- EX-5b: Withdrawn. The `mysql` recipe moved to kadet-hub/recipes, whose
  RCP-16 keeps it on MySQL's 9.7 LTS line with the same package rule.

  - Since: #32; withdrawn: #68

- EX-6: A check that deploys to a kind cluster MUST fail within about a
  minute once a pod is broken.

  A pod is broken when one of its containers waits with
  `CrashLoopBackOff`, `ImagePullBackOff`, `CreateContainerConfigError` or
  `InvalidImageName`, or has restarted more
  than three times, on two polls in a row. One poll is not enough:
  Argo CD's server waits with `CreateContainerConfigError` for the
  `argocd-redis` Secret until the redis pod's init container has created
  it, and the watcher stopped a healthy install on that in CI. Two polls
  did not always cover that wait; EX-7 therefore starts those pods only
  once the Secret exists. Each such `check` polls the pods of all
  namespaces every 10 seconds from the creation of the kind cluster until
  Chainsaw ends, so a broken pod also stops the operator installs. On the
  first broken pod it prints the pod's description and its containers'
  logs and stops the command `check` waits for, an operator's `rollout
  status` or `wait`, or Chainsaw.
  The watch sits in `check` because Chainsaw runs the operations of a test
  one after another and has none that runs beside an assert.

  When a `rollout status` or `wait` of an operator times out, `check` prints the
  namespace's events sorted by time, `kubectl get pods -o wide`, and the
  description and logs of every pod that is not ready. Without them the
  timeout names only the Deployments that did not become available.

  Every apply, of an operator as of the compiled output,
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

  - Test: `examples` workflow, the jobs that deploy to kind; the
    fail-fast path by hand, with a non-existent image tag in one of their
    classes
  - Since: #8, #10, #13, #16, #17, #20, #31; operators from the compiled target: #21;
    rabbitmq moved: #79; recipes moved: #81

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

## KubeVirt CSI driver

`kubevirt-csi/` runs the KubeVirt CSI driver that the kubevirt generator
renders, end to end on one kind cluster. The kind cluster is the infra
cluster. It runs KubeVirt, CDI and one VM, and that VM runs a single-node
k3s cluster, the tenant. A PVC in the tenant becomes a DataVolume in the
infra cluster, which KubeVirt hotplugs into the VM as a disk.

One Kapitan project compiles two targets with the kubevirt generator,
pinned by version and digest in `inventory/classes/generators.yml` and
verified and pulled as in EX-4. Target `infra` renders the KubeVirt CR,
the VM `tenant` and the driver's controller with its RBAC into the
namespace `tenant`. Target `tenant` renders the node plugin, the CSIDriver
and the default StorageClass `kubevirt`, whose volumes use kind's
`standard` class in the infra cluster. The snapshot controller stays off,
because the check takes no snapshot.

The generator renders neither the operators nor a CDI CR. `check` applies
the KubeVirt and CDI operators from their release manifests, pinned by
version and sha256. `infra.yaml` holds what else the infra cluster needs:
the namespace `tenant`, the CDI CR of the pinned release and the Service
`tenant-api`, through which the controller reaches the tenant API.

The VM boots the Debian 13 containerdisk, pinned as
`13@sha256:<digest>`. quay.io/containerdisks publishes date tags in two
schemes, so Renovate follows the digest of `13`. Its cloud-init script
downloads k3s by version and sha256, starts it and annotates the node with
the VM's name and namespace, which the driver reads to find the VM to
hotplug into. `check` reads the admin kubeconfig over `virtctl ssh` with a
key pair it creates per run and passes to the VM through
`accessCredentials`, and reaches the tenant API from the host through
`virtctl port-forward`.

`check` applies the tenant side before the infra side, because the
controller's kubeconfig Secret is built from the token Secret that the
tenant's token controller fills. It applies the tenant Namespace first and
the ServiceAccount `kubevirt-csi-controller-sa` before the rest, because
the token controller deletes a token Secret whose ServiceAccount does not
exist yet (generator README, Prerequisites).

CDI has no StorageProfile entry for kind's `rancher.io/local-path`
provisioner, and the driver's DataVolumes name no access mode. `check`
therefore patches the StorageProfile `standard` with `ReadWriteOnce` and
`Filesystem`. Without the patch the DataVolumes stay Pending.

- EX-14: `kubevirt-csi/check` MUST fail unless a PVC of the tenant's
  StorageClass `kubevirt` is provisioned through the KubeVirt CSI driver
  and its pod reads back what it wrote.

  Provisioned through the driver means all of the following. The PVC is
  Bound to a PV of driver `csi.kubevirt.io`. The PV's volume handle names
  a DataVolume in the infra namespace `tenant` that carries the label
  `csi-driver/cluster: tenant` from `infra_cluster_labels` and has
  succeeded. The VMI `tenant` reports a hotplug volume of that name as
  Ready. The pod's `/data` is mounted from the device that the VMI names as
  the volume's target. A PVC bound by another provisioner, or a volume that
  never reaches the VM, fails one of these.

  `check` runs the same assertions against a second claim and fails unless
  they reject it. `tests/static-pvc.yaml` binds that claim to a hostPath
  PV of StorageClass `static`, which no provisioner serves, so the claim is
  Bound without the driver. The assertions must stop on the PV's driver.
  This takes seconds and needs no second cluster.

  The job's `timeout-minutes` is 20. In the first run of #60 the job took
  4 minutes 22 seconds on an ubuntu-24.04 runner, 1 minute 47 seconds of
  it waiting for KubeVirt and CDI to become Available.

  - Test: `examples` workflow, job `kubevirt-csi`; the negative case on
    `tests/static-pvc.yaml` in the same `check`
  - Since: #60

- EX-14a: `kubevirt-csi/check` MUST fail at once, naming KVM, when the host
  has no `/dev/kvm` or KubeVirt reports no allocatable
  `devices.kubevirt.io/kvm` on the kind node.

  KubeVirt does not emulate without KVM unless `useEmulation` is set, so
  without it the VM stays unscheduled and the check would wait out its
  timeouts. GitHub's ubuntu-24.04 runners expose `/dev/kvm`.

  - Test: `examples` workflow, job `kubevirt-csi` (partial: the missing
    case only by hand, on a host without `/dev/kvm`)
  - Since: #60

## Open WebUI and SearXNG

`open-webui-searxng/` backs the kadet-hub.org blog post on a self-hosted
chat assistant with web search, put together from published recipes of
kadet-hub/recipes. Open WebUI is the chat interface and API, Ollama runs
the model on the CPU and SearXNG is Open WebUI's web search.

The fetch inventory `fetch/targets/recipes.yml` pins `open-webui` and
`searxng` by version and digest, the recipes the targets include, as the
registry's `docs/consumers.md` asks since kadet-hub/registry#536. `check`
adds the recipes their index records list under `includes`, at the
versions and digests listed there, as the consumer workflow does.
`open-webui` includes `ollama` and `valkey`, `searxng` includes `valkey`,
both at the digest of valkey 1.0.2, so the two share one
`inventory/classes/recipes/valkey`. `check` does not compile the fetch
inventory. It verifies and pulls each recipe as "Verifying a recipe by
hand" in the registry's `docs/consumers.md` describes, and each generator
the recipes pin as in EX-4. The recipes are written for the omegaconf
backend, which `.kapitan` selects.

Each recipe gets a target and a namespace of its own, `searxng` and
`open-webui`, and each target runs the Valkey of its included recipe. The
target `searxng` adds `json` to `search.formats`: SearXNG's settings
template enables `html` only and answers `format=json`, which Open WebUI
asks for, with 403. The target `open-webui` sets `ENABLE_WEB_SEARCH`,
`WEB_SEARCH_ENGINE` and `SEARXNG_QUERY_URL`, the last to the Service
`searxng` in the namespace `searxng`. The secrets are refs with the base64
backend and a `random` function, which the first compile creates in a
temporary refs path and the second writes with `--reveal`. The images of
SearXNG, Open WebUI and Ollama run as root, so both namespaces enforce the
Pod Security level `baseline`.

- EX-17: `open-webui-searxng/check` MUST fail unless every recipe of the
  fetch inventory, and every recipe its record lists under `includes` at
  the version and digest listed there, is listed in the attested index at
  that version and digest, is not yanked and has a valid attestation, no
  recipe is wanted at two digests, the recipes come to four, every
  generator the recipes pin passes EX-4, and, deployed to a new kind cluster, Open WebUI's
  web search returns at least one result, the same search fails once
  SearXNG is scaled to zero, and `smollm:135m`, pulled into Ollama through
  Open WebUI, answers a chat completion through Open WebUI.

  `check` signs up the first account, which Open WebUI makes admin, and
  calls `/api/v1/retrieval/process/web/search` with the query
  `kubernetes`. Open WebUI sends the query to SearXNG with `format=json`,
  loads the pages of the results and embeds them with the model its image
  ships. With SearXNG scaled to zero the same call must return 400, and
  Open WebUI's log must show that it cannot connect to the host of
  `SEARXNG_QUERY_URL`. SearXNG is the only search engine Open WebUI is
  configured with, so the results of the first call come from SearXNG.

  searxng 1.0.1 has a readiness probe on `/healthz` (RCP-185 in
  kadet-hub/recipes), so the rollout of SearXNG ends once it answers.
  open-webui 1.0.0 has none, so its rollout ends before Open WebUI
  listens. `check` waits for Open WebUI's `/health` through the API server
  and starts the port-forward only then, because a port-forward ends at
  the first connection the pod refuses. That ended the first run of #132.
  kadet-hub/recipes#109 adds the probe to open-webui.

  The results, and the pages Open WebUI loads for them, come from outside
  the cluster, so this step can fail without a change to the repository.
  In the first green run of #132 on an ubuntu-24.04 runner, SearXNG got
  results from Brave and Google CSE and a CAPTCHA from DuckDuckGo. When
  every engine refuses the runner, Open WebUI 0.12.5 answers 404 with `No
  results found from web search` (`process_web_search` in
  `routers/retrieval.py`), and `check` fails and prints the engines that
  did not answer. A rerun starts on a new runner, which may get another
  address. `check` prints the engines that answered on success as well,
  so the job logs show how often that happens.

  - Test: `examples` workflow, job `open-webui-searxng`; `manual:` with
    searxng set back to 1.0.0 in the fetch inventory, Renovate 44.194.0
    (`--platform=local --dry-run=lookup`, 2026-11-05) with the org preset
    alone proposed 1.0.1 at its digest on the branch
    `renovate/open-webui-searxng-recipes`
  - Since: #132; includes from the index and searxng 1.0.1: #154

## Platform baseline

`platform-baseline/` backs the kadet-hub.org blog post on a cluster's
platform layer kept in one Kapitan inventory. The generators render what a
platform team configures: a private CA as cert-manager ClusterIssuers, a
Kyverno policy, a Prometheus and a Grafana with that Prometheus as its data
source, an External Secrets ClusterSecretStore, Velero's backup location
and schedule, and Argo CD's project and Applications. podinfo is the app on
top. Its target renders a Certificate, an ExternalSecret and a
ServiceMonitor next to the Deployment, and Argo CD deploys it.

The generators render custom resources only, not the operators that read
them. cert-manager comes from the kadet-hub recipe `cert-manager`, pinned
in the fetch inventory `fetch/targets/recipes.yml` and compiled into
`compiled/cert-manager/manifests`. kadet-hub publishes no recipe for the
other operators, so `check` installs them from their projects' release
artifacts: Kyverno's `install.yaml`, the Prometheus Operator's
`bundle.yaml`, External Secrets' `external-secrets.yaml` and the Grafana
Operator's `kustomize-cluster_scoped.yaml`, each pinned by version and
sha256, Argo CD's `install.yaml` at the commit of its tag as in EX-7, and
Velero through `velero install` with the server and AWS plugin images
pinned by digest. The manifests of the Prometheus Operator and of External
Secrets install into the namespace `default`, and `check` leaves them
there.

There is one target per component, `cert-manager`, `kyverno`,
`monitoring`, `external-secrets`, `velero` and `argocd`, and the target
`podinfo`. The class `platform` holds the values more than one resource
reads: domain, issuer, secret store, the secrets namespace, the Git
repository and the labels of app namespaces. The class `generators` pins
the generators. The kubernetes generator is missing from it, because the
recipe pins it and both would unpack into `lib/kubernetes`. `check` fails
when one generator is pinned at two digests. The recipe is written for the
omegaconf backend, which `.kapitan` selects.

podinfo's target publishes the Kapitan topic `argocd`, and the target
`argocd` turns each publisher into an Application in the project `apps`.
The Application syncs automatically, reads its path recursively, and
creates its namespace with `CreateNamespace=true` and the labels of
`platform.tenant_labels`. The project allows Namespace as the only
cluster-scoped kind, which `CreateNamespace=true` needs. The Kyverno
policy selects namespaces by the same labels. The ExternalSecret has the
sync wave `-1`, so Argo CD creates the Deployment once its Secret exists.
A pod that starts before the Secret waits with `CreateContainerConfigError`,
which EX-6 counts as broken when it lasts two polls. The certmanager generator 1.0.4 renders no annotations,
so the Certificate has no wave. A Secret volume that does not exist yet
keeps the pod in `ContainerCreating`, which EX-6 does not count.

Two stand-ins replace what lives outside a cluster. `git-server.yaml` is
the Gitea of EX-7, and `check` pushes `compiled/podinfo` to it.
`s3-server.yaml` runs Versity's S3 gateway (versitygw, Apache-2.0) with its
posix backend, where a bucket is a directory, so `mkdir` creates Velero's
bucket. MinIO was considered. On 2026-11-04 neither `quay.io/minio/minio`
nor `docker.io/minio/minio` listed its tags to an anonymous client, so
there was no image to pin. `check` creates the gateway's keys, Velero's
credentials and the message in the secrets namespace with random values,
so none of them is in the repository.

- EX-18: `platform-baseline/check` MUST fail unless the recipe of the
  fetch inventory and every generator pass the checks of EX-17 and EX-4,
  and, deployed to a new kind cluster:

  - Argo CD reports the Application `podinfo` `Synced` at the pushed
    commit and `Healthy`, with one resource per file of
    `compiled/podinfo`, each `Synced`;
  - podinfo serves HTTPS with a certificate that verifies against the
    platform CA for `podinfo.<domain>`, and returns the message stored in
    the secrets namespace;
  - Kyverno denies a pod in namespace `podinfo` whose image has a tag and
    no digest, admits the same pod with the digest, and admits the
    tag-only pod in namespace `default` in a server-side dry run;
  - Prometheus answers `up{namespace="podinfo"}` with 1 for every series,
    and Grafana returns the same through its data source `prometheus`;
  - a changed message in the secrets namespace reaches podinfo's Secret
    within 120 seconds;
  - a Velero backup of the secrets namespace completes, the namespace is
    deleted, and a restore completes and brings back the Secret with the
    changed message.

  An Application whose path holds no manifest is `Synced` and `Healthy`
  too. The first local run passed that way, while the Application read
  only the top level of `podinfo/`, where the generators write a
  directory per namespace. `Healthy` covers the Certificate and the
  ExternalSecret, through Argo CD's built-in health checks for both
  kinds.

  The certificate check uses `curl --cacert` with the CA from the Secret
  of the CA Certificate, and `--resolve` to the port-forward, so the
  hostname is checked against the certificate without DNS. Velero backs up
  the secrets namespace because Git does not hold its content. Argo CD
  would recreate podinfo's namespace after a delete, so a restore of it
  would prove nothing. External Secrets also defines a kind `Grafana`, in
  `generators.external-secrets.io`, so `check` names the Grafana
  Operator's kinds with their group.

  `velero install` 1.18.4 names the plugin's init container
  `velero-velero-plugin-for-aws:v1-14-4` for an image given as
  `tag@digest`, which the API server rejects. `check` renders the install
  with `--dry-run -o json` and sets the name the CLI gives the same image
  without a digest.

  Related: EX-6, EX-7, EX-12

  - Test: `examples` workflow, job `platform-baseline`; `manual:` Renovate
    44.194.0 (`--platform=local --dry-run=lookup`, 2026-11-05) found every
    pin of `platform-baseline`, and with External Secrets set back to
    v2.13.0 proposed v2.14.0 with the sha256 of its `external-secrets.yaml`
  - Since: #135

- EX-18a: `platform-baseline/check` MUST fail unless compiling a copy of
  the inventory with another `platform.domain` changes exactly
  `compiled/cert-manager/issuers/cert-manager/platform-ca-cert.yml` and
  `compiled/podinfo/podinfo/podinfo-tls-cert.yml`.

  The domain is the root CA's common name in the target `cert-manager` and
  podinfo's DNS name in the target `podinfo`. The post shows the diff.

  - Test: `examples` workflow, job `platform-baseline`
  - Since: #135

## Immich and CloudNativePG

`immich-cnpg/` backs the kadet-hub.org blog post on a self-hosted photo
library, put together from published recipes of kadet-hub/recipes.
Immich is the photo server with its web interface and API, and runs its
machine learning service on the CPU. PostgreSQL runs as a CloudNativePG
Cluster, and Valkey holds Immich's job queue.

The fetch inventory `fetch/targets/recipes.yml` pins `immich`,
`postgresql`, `valkey` and `cnpg` by version and digest. `immich`
includes `postgresql` and `valkey` at the digests pinned there.
`postgresql` requires the operator `cnpg`, which runs once per cluster
and gets a target of its own. `check` verifies and pulls the recipes and
generators as `open-webui-searxng/check` does.

The target `cnpg` deploys to the namespace `cnpg-system`, which enforces
the Pod Security level `restricted`. The target `immich` deploys to
`immich`, which enforces `baseline`, because Immich's server and machine
learning images run as root. `check` applies both server-side, because a
client-side apply stores the object in an annotation, which the API
server refuses for CRDs above 256 KiB, such as CloudNativePG's.
It applies the Cluster of `immich` first and waits until it is ready.
Immich's server exits while PostgreSQL refuses connections. In the first
local run it had restarted twice and waited in `CrashLoopBackOff` when
EX-6 stopped the check. The target sets one PostgreSQL instance, because
further instances on the one kind node would share its disk. The Valkey
password is a ref as in EX-17.

- EX-19: `immich-cnpg/check` MUST fail unless the recipes and generators
  pass the checks of EX-17 and, deployed to a new kind cluster with
  `cnpg` first, Immich sorts uploaded photos into its timeline by their
  EXIF dates and reverse-geocodes their GPS positions, a second user sees
  an album shared with them and no other photo, smart search finds a
  photo by its colour, a database backup in the library claim restores
  the photos' records, and photos, metadata and album survive deleting
  the server pod and the PostgreSQL pod.

  `check` generates four JPEGs with Pillow, each filled with one colour,
  with `DateTimeOriginal`, `OffsetTimeOriginal` and a GPS position in
  their EXIF data. It uploads them with the file dates set to the time of
  the upload, so the timeline can take their dates from the EXIF data
  only. The photo taken in New York at 23:30 on 31 December 2023, UTC-5,
  falls on 1 January in UTC and must land in the December bucket, because
  Immich buckets by local time. Each photo's position must match its
  EXIF data to 0.00001 degrees, and its country must be the expected one.

  Immich reverse-geocodes offline. On its first start the server imports
  the GeoNames places with 500 or more inhabitants that its image ships
  into PostgreSQL, and it looks up the nearest one with `earthdistance`,
  the extension of the option `earthdistance` of `postgresql`. `check`
  prints the city and does not compare it, because the nearest place is
  not always the expected one: in the first CI run of #137, on an
  ubuntu-24.04 runner, Times Square resolved to Weehawken, New Jersey,
  across the Hudson.

  The admin creates the second user, who gets 400 for the photo of the
  Eiffel Tower before the album `Paris 2024` with it is shared with them
  as viewer. Afterwards they must see the album, its two photos in its
  timeline bucket and the thumbnail of one, and still get 400 for the
  photo from New York.

  Smart search embeds each photo with the CLIP model `ViT-B-32__openai`
  and stores the vectors with pgvector, the extension of the option
  `pgvector`. Machine learning downloads the model from Hugging Face when
  the first photo needs it. `check` waits until a search finds all four
  photos, then requires the photo of each colour first for "a red photo"
  and the three other colours. In the first CI run of #137 the search
  found all four photos 16 seconds after their metadata, with 606 MB of
  CLIP model downloaded. Hugging Face is outside the cluster, so this
  step can fail without a change to the repository, as the web search of
  EX-17 can.

  `check` starts Immich's job `backup-database`, which writes a `pg_dump`
  of the database as its owner into `backups/` on the library claim.
  Immich runs the same job every night at 02:00 and keeps the last 14
  dumps. `check` copies the claim with `tar` through `kubectl exec`; the
  copy must hold every original byte for byte. It restores the dump with
  `psql` as the superuser into an empty database of the same Cluster,
  which must hold the four photos' checksums and the album's viewer. A
  CloudNativePG backup needs an object store or volume snapshots, and
  kind offers neither. It is not tested, and neither is a restore through
  Immich, which the README of the `immich` recipe expects to fail as the
  owner.

  After deleting the server pod, and again after deleting the PostgreSQL
  pod, `check` requires the four photos in the timeline, the country of
  one, the original of another byte for byte and the album as the second
  user sees it. With one instance, CloudNativePG creates the PostgreSQL
  pod again on the same claim. `kubectl delete` of that pod waits for the
  instance manager, which shuts PostgreSQL down smart first and waits up
  to `smartShutdownTimeout`, 180 seconds by default, for the clients to
  disconnect. Immich keeps its connections open, so the delete took 182
  seconds in the first CI run of #137.

  - Test: `examples` workflow, job `immich-cnpg`; `manual:` with cnpg set
    back to 1.0.1 in the fetch inventory, Renovate 44.194.0
    (`--platform=local --dry-run=lookup`, 2026-11-05) proposed 1.0.2 at
    its digest on the branch `renovate/immich-cnpg-recipes`
  - Since: #137

## Pi-hole and PowerDNS

`pihole-powerdns/` backs the kadet-hub.org blog post on DNS for a home or
office network, put together from published recipes of kadet-hub/recipes.
PowerDNS is authoritative for the home zone. external-dns writes a record
into that zone for every annotated Service. Pi-hole is the resolver the
clients ask. It forwards the home zone to PowerDNS and every other name to
its upstream.

The fetch inventory `fetch/targets/recipes.yml` pins `pihole`,
`external-dns-powerdns` and `powerdns` by version and digest.
`external-dns-powerdns` 1.0.0 includes `powerdns` 1.0.0, so the fetch
inventory pins powerdns 1.0.0, not the later 1.0.1. A Renovate pull request
that moves powerdns to 1.0.1 alone fails `check` until an
external-dns-powerdns version that includes 1.0.1 is listed. `check`
verifies and pulls the recipes and the generator they pin as in EX-17.

The target `dns` renders PowerDNS and external-dns into the namespace
`dns`, at the Pod Security level `restricted`. The target `pihole` renders
Pi-hole into `pihole`, at `baseline`, because Pi-hole's image starts as
root. The class `home` sets the zone `home.example` once for both targets.

The target `pihole` wires Pi-hole through `components.pihole.env`.
`FTLCONF_misc_dnsmasq_lines` adds
`server=/home.example/powerdns.dns.svc.cluster.local` to the dnsmasq
configuration. FTL's dnsmasq resolves a server name with `getaddrinfo` when
it reads its configuration (`parse_server` in `src/dnsmasq/option.c` of FTL
v6.8). `check` therefore deploys `dns` before `pihole`, and Pi-hole needs a
restart when the Service `powerdns` is recreated with a new cluster IP.
Pi-hole's conditional forwarding, `dns.revServers`, writes the same
`server=` line, but it also requires the CIDR of a reverse zone, which
PowerDNS does not serve here. `FTLCONF_dns_upstreams` points Pi-hole at
the cluster's DNS, as the pihole recipe's test target does. The Service
`pihole` carries the annotation
`external-dns.kubernetes.io/hostname: pihole.home.example`, so external-dns
writes the Service's cluster IP into the zone.

- EX-20: `pihole-powerdns/check` MUST fail unless the recipes of the fetch
  inventory and every generator pass the checks of EX-17 and EX-4, and,
  deployed to a new kind cluster, a client pod that asks Pi-hole gets the
  cluster IP of the Service `pihole` for `pihole.home.example` over UDP
  and TCP, NXDOMAIN with the SOA of `home.example` for a name the zone
  lacks, and `0.0.0.0` over UDP and TCP for `ads.example` once it is
  denied through Pi-hole's API.

  The client is a pod of Pi-hole's image, which brings `dig` and `curl`.
  `check` first waits until PowerDNS itself answers `pihole.home.example`
  with the Service's cluster IP. external-dns syncs every 10 seconds.
  The SOA's contact is `hostmaster.home.example`, which PowerDNS derives
  from the zone name. Neither the cluster's DNS nor the root servers
  answer with that SOA, so the NXDOMAIN comes from PowerDNS through
  Pi-hole. The SOA's primary name server is
  `a.misconfigured.dns.server.invalid`, PowerDNS's `default-soa-content`,
  because the powerdns recipe 1.0.0 sets none, and `check` does not test
  it. `ads.example` lies under the reserved TLD
  `.example`. `check` requires NXDOMAIN for it before the deny entry, so
  the `0.0.0.0` afterwards comes from the entry and not from the blocklist
  that Pi-hole downloads at its first start.

  Not tested: an Ingress as the source of a record, because
  external-dns-powerdns 1.0.0 reads Services only (`--source=service`) and
  its ClusterRole grants no access to Ingresses. A LoadBalancer Service
  for Pi-hole, which clients on a LAN need and kind does not provide. The
  downloaded blocklist, and Pi-hole as the DHCP server.

  - Test: `examples` workflow, job `pihole-powerdns`
  - Since: #138

## Helmfile and Kapitan

`helmfile-vs-kapitan/` backs the kadet-hub.org blog post that compares
Helmfile with Kapitan on a setup Helmfile is usually chosen for: two
upstream charts, podinfo and Valkey as its cache, in the environments `dev`
and `prod`. Both sides pin the charts at the same version and OCI digest
and render them with the same helm binary. `helmfile/helmfile.yaml` lists
the two releases, `helmfile/environments/` holds what differs per
environment, and `helmfile/values/` holds the chart values as Go
templates that read it. The targets in `kapitan/inventory/targets/` hold
the same values as parameters, and the classes `podinfo` and `valkey`
render the charts with Kapitan's `helm` input. The release `podinfo`
`needs` `valkey`.

podinfo logs in to Valkey as the user `default`. Its chart value
`extraEnvs` reads the password from the Secret `valkey-auth` and builds
`PODINFO_CACHE_SERVER` from it with the kubelet's `$(VAR)` expansion.
`check` creates the password per run. Helmfile reads it through vals from
the environment, `ref+envsubst://$VALKEY_PASSWORD`, and passes it to the
chart, which writes it base64-encoded into `valkey-auth`. Kapitan reads it
from the ref `?{base64:valkey/password}`, which `check` writes to a
temporary refs path. Kapitan hands `helm_values` to Helm as written and
reveals refs only in its own output. Given to the chart, the ref tag ends up
base64-encoded in the chart's Secret, where `--reveal` does not find it.
The class `valkey` therefore drops the chart's `secret.yaml` with the
`remove` input, and the kubernetes generator writes `valkey-auth` with the
ref in `stringData`. Helmfile with vals turned off,
`HELMFILE_DISABLE_VALS=true`, hands the chart the `ref+` string, which
ends up base64-encoded in the same way.

`check` normalizes both sides as `same-app` does (EX-1), with two rules
of its own. An object without a namespace gets `podinfo`, the namespace
both sides give Helm. A Secret is compared by name, namespace, type and
decoded data, because on the Kapitan side the generator writes it, with its
own labels. An empty object list fails the check.

- EX-21: `helmfile-vs-kapitan/check` MUST fail unless, for `dev` and
  `prod`, the normalized output of `helmfile template` equals that of
  `kapitan compile --reveal`, Helmfile's output holds the password
  base64-encoded, Kapitan's output without `--reveal` holds neither the
  password nor its base64 encoding but the ref token in `valkey-auth`, a
  compile without the `remove` entry leaves the ref tag in the chart's
  Secret after `--reveal`, `helmfile template` with
  `HELMFILE_DISABLE_VALS=true` leaves the `ref+` string in it, and `prod`,
  deployed to a new kind cluster with `helmfile sync` and then with
  `kubectl apply` of Kapitan's output, lets podinfo store and read a key in
  Valkey, which refuses `valkey-cli` without the password. `helmfile sync`
  MUST process `valkey` in an earlier group than `podinfo`.

  Helmfile 1.8.2 logs its groups at the log level `debug` only, which
  `check` sets for `sync`. `check` prints that log when `sync` fails. It
  holds the password neither plain nor base64-encoded, as `grep` showed
  for a local `sync` of `prod` on kind on 2026-11-05.

  `check` writes and reads the key through the API server's service proxy.
  `kubectl create --raw` exits 0 when podinfo answers the write with an
  error, and prints the answer, while the 202 of a write has no body. In
  the second CI run of #140 the read right after the Helmfile rollout found
  no key. Locally, with Valkey scaled to zero and back to one, podinfo
  answered five writes with 500 `cache set failed` and stored the sixth,
  11 seconds later. `check` therefore repeats write and read for up to a
  minute until the read returns the value. A wrong password keeps the write
  failing and fails the check.
  Between the two deploys it runs `helmfile destroy` and deletes the
  namespace. After the Kapitan deploy `helm list` must be empty. The
  Kapitan side has no order. podinfo starts while Valkey is down and
  connects later (`startCachePool` in podinfo 6.17.0), so it needs none.

  Not tested: `helmfile diff` and `helmfile apply`, which need the
  helm-diff plugin; helm-secrets with sops; vals backends other than
  `envsubst`; `dev` on a cluster.

  Related: EX-1, EX-4, EX-6, EX-12

  - Test: `examples` workflow, job `helmfile-vs-kapitan`; `manual:` with
    prod's podinfo replicas changed in `kapitan/inventory/targets/prod.yml`
    alone, `check` fails on the Deployment's `replicas`; `manual:` with
    `valkey-auth` changed after the deploy and podinfo restarted, all 30
    writes got 500 and podinfo logged `WRONGPASS`; `manual:` with
    podinfo set back to 6.16.0 and Valkey to 0.12.0 on both sides, Renovate
    44.194.0 (`--platform=local --dry-run=lookup`, 2026-11-05) proposed
    6.17.0 and 0.12.1 at their digests for all four pins on the branch
    `renovate/helmfile-vs-kapitan-charts`
  - Since: #140

## Timoni modules and bundles

`timoni-vs-kapitan/` backs the kadet-hub.org blog post that compares
Timoni with Kapitan. Both sides render the app of `same-app`: namespace
`shop`, apps `web` and `api`, environments dev and prod. The Kapitan side
is the inventory of `config-tools`.

The Timoni module `timoni/app` declares the values schema `#Config` and
one template per kind. The templates are typed with the Kubernetes 1.37
API schemas that `timoni mod vendor k8s -v 1.37` wrote to `cue.mod/gen`.
The bundle `timoni/shop.cue` declares the instances `web` and `api` and the
values both environments share, and `timoni/dev.cue` and `timoni/prod.cue`
add the values of one environment. The api's `web_url` is built in the
bundle from the web instance's namespace and Service port, as the
inventory builds it with interpolation.

The bundle names the module by registry URL and version,
`oci://localhost:5001/modules/app` at 1.0.0. `check` starts a registry
from the `registry` image on that port, pushes `timoni/app` with
`timoni mod push` and pins the bundle to the digest of that push through
a bundle file it writes. The digest is not committed: `timoni mod push`
annotates the artifact with the Git commit and its time, so the digest
changes with every commit.

- EX-22: `timoni-vs-kapitan/check` MUST fail unless Timoni and Kapitan
  render the same manifests for dev and prod.

  Both renderings are normalized as in `config-tools`: one document per
  object, sorted, keys sorted. Only the label `app.kubernetes.io/managed-by`
  is dropped, which the Kapitan generator alone sets. The module sets the
  Service port's `appProtocol` and the fields the generator writes out,
  such as the probe thresholds and `defaultMode: 420`.

  - Test: `examples` workflow, job `timoni-vs-kapitan`
  - Since: #142

- EX-22a: `timoni-vs-kapitan/check` MUST fail unless Timoni refuses the
  pinned bundle after a second push moved the tag 1.0.0, and builds the
  second push from the bundle without the pin.

  The second push sets `imagePullPolicy: Always` in the module. Timoni
  compares the digest the registry returns for the version with the
  pinned one and reports that they do not match.

  - Test: `examples` workflow, job `timoni-vs-kapitan`
  - Since: #142

- EX-22b: `timoni-vs-kapitan/check` MUST fail unless Timoni rejects the
  prod bundle with `replica: 3` in place of `replicas: 3` for web, and
  Kapitan compiles the same change in its prod target to a Deployment
  `web` with `replicas: 1`.

  `#Config` is a CUE definition, and a definition is closed, so Timoni
  reports `replica: field not allowed`. Kapitan 0.36.3 and the kubernetes
  generator 1.14.0 ignore a key they do not know. The generator falls
  back to one replica and logs that `pdb_min_available` 2 then allows no
  eviction, a warning that the compile does not fail on.

  - Test: `examples` workflow, job `timoni-vs-kapitan`
  - Since: #142

Not tested: signing and verifying the module with cosign, `timoni bundle
apply` on a cluster, and runtime values in bundles.

## KCL modules

`kcl-vs-kapitan/` backs the kadet-hub.org blog post that compares KCL
with Kapitan, on the app and the Kapitan inventory of
`timoni-vs-kapitan`.

`kcl/app/app.k` declares the schema `App` and a function that renders an
app's objects with the schemas of the `k8s` module. `kcl/shop.k` declares
`web` and `api` with the values both environments share and prints their
objects as one YAML stream. `kcl run shop.k prod.k` merges the values of
`prod.k` into `web` and `api`. `kcl.mod` declares `k8s = "1.36"`, which
kcl pulls from `ghcr.io/kcl-lang/k8s` by that tag, and `kcl.mod.lock`
records its checksum. `check` sets `KCL_PKG_PATH` to a temporary
directory, so every run downloads the module.

- EX-23: `kcl-vs-kapitan/check` MUST fail unless KCL and Kapitan render
  the same manifests for dev and prod, normalized as in EX-22.

  - Test: `examples` workflow, job `kcl-vs-kapitan`
  - Since: #142

- EX-23a: `kcl-vs-kapitan/check` MUST fail unless KCL rejects
  `replica = 3` in place of `replicas = 3` for web in prod, and Kapitan
  compiles the same change as in EX-22b.

  A KCL schema is closed. kcl reports `Cannot add member 'replica' to
  schema 'App'` at the line in `prod.k` and suggests `replicas`.

  - Test: `examples` workflow, job `kcl-vs-kapitan`
  - Since: #142

- EX-23b: `kcl-vs-kapitan/check` MUST fail unless kcl, given a wrong
  `sum` for the `k8s` module in `kcl.mod.lock` and an empty module
  directory, downloads the module and renders the same prod manifests.

  The post states that the lock file records the checksum and that kcl
  0.13.3 does not compare it, and this check fails once that changes.
  kcl 0.13.3 builds on kpm 0.13.2, which checks a dependency's sum only
  behind the feature gate `SupportModCheck` (`KPM_FEATURE_GATES`), off by
  default.

  - Test: `examples` workflow, job `kcl-vs-kapitan`; `manual:` with
    `KPM_FEATURE_GATES=SupportModCheck=true` and a wrong sum, `kcl run`
    still rendered on 2026-11-05
  - Since: #142

Not tested: publishing the app as a KCL module with `kcl mod push`, and
KCL's other outputs than YAML.

## Argo CD config management plugin

`argocd-cmp/` backs the kadet-hub.org blog post for teams that will not add
a compile step to CI and want Argo CD to compile the Kapitan project. A
config management plugin runs `kapitan compile` in a sidecar of Argo CD's
repo server, and the Application names the plugin and the target. The
project uses the recipe `blackbox-exporter`, which includes no other
recipe, pinned in the fetch inventory `fetch/targets/recipes.yml`.

The Application creates the namespace with the Pod Security level
`restricted`. The recipe 1.0.0 sets no seccomp profile, which that level
requires, so the target adds `RuntimeDefault` to the container's
`security_context`.

`check` installs Argo CD from its release manifest at the commit of its
tag, in the two steps of EX-7 and with the redis image of EX-7. It then
applies the ConfigMap of `kapitan-plugin.yaml` and patches the Deployment
`argocd-repo-server` with `repo-server-patch.yaml`. The argocd generator
renders Applications, ApplicationSets and AppProjects, and its README
leaves the installation to the `helm` input, so it cannot add the sidecar.
The sidecar runs Kapitan's image, pinned as `tag@sha256:digest`, as user
999 with Argo CD's `argocd-cmp-server` as its command, as Argo CD's
documentation requires. The plugin has no `discover` section, so it
renders only Applications that name it. The Application passes the target
in its plugin env `TARGET`, which the plugin reads as `ARGOCD_ENV_TARGET`.

The plugin compiles without `--fetch` (EX-4). `check` verifies and pulls
the recipe and the kubernetes generator it pins as `pihole-powerdns/check`
does and pushes them with `.kapitan`, `fetch/` and `inventory/` to the
Gitea of EX-7. A sidecar could not fetch the recipe with `kapitan compile
--fetch` alone in any case, because Kapitan 0.36.3 reads the inventory,
which includes the recipe, before it fetches (kapicorp/kapitan#1638).
`generate` prints every `.yml` and `.yaml` file under `compiled/<target>`
and fails when there is none. Argo CD's documentation warns that a plugin
that prints nothing makes an Application with `prune` delete its
resources.

- EX-24: `argocd-cmp/check` MUST fail unless the recipe and the generator
  pass the checks of EX-17 and EX-4, and, in a new kind cluster with Argo
  CD and the sidecar:

  - the sidecar has no service account token, opens a TCP connection to
    ghcr.io on port 443, and cannot open it once `repo-server-egress.yaml`
    applies;
  - Argo CD reports the Application `blackbox-exporter` with source type
    `Plugin`, `Synced` at the pushed commit and `Healthy`, and the
    exporter's Deployment has one replica, available;
  - after a commit that sets `replicas` to 2 in the target, and a refresh,
    the same holds at the new commit with two replicas.

  The post says what the sidecar can reach, and these steps check it.
  Argo CD's manifest sets `automountServiceAccountToken: false` on the
  repo server's pod, so no container in it can call the API server with
  the pod's identity. Its NetworkPolicies restrict ingress only, so the
  sidecar reaches the internet until a policy restricts egress.
  `repo-server-egress.yaml` allows DNS, Argo CD's Redis and the Git server,
  and both commits render under it, which shows that the plugin needs no
  other network. The connection test runs the sidecar's Python. `check`
  waits up to a minute for the policy to take effect and fails when it
  does not, so a CNI that ignores NetworkPolicy fails the check. kindnet,
  the CNI that kind v0.33.0 installs, enforces it.

  After the second push `check` sets the annotation
  `argocd.argoproj.io/refresh: normal`, which is what Argo CD's webhook
  handler sets on a push event (`RefreshApp` in `util/argo/argo.go`).
  Without a webhook Argo CD polls the repository every
  `timeout.reconciliation`, 120 seconds by default, plus up to 60 seconds
  of jitter.

  Refs are not tested. The recipe renders no Secret, and the plugin passes
  no `--reveal`. The repository's `.kapitan` can still set `reveal` and
  `fetch` for every compile (`from_dot_kapitan` in Kapitan 0.36.3's
  `cli.py`), so the plugin's command line does not keep a compile from
  revealing refs or fetching. What keeps refs closed is that the sidecar
  holds no key for them.

  Related: EX-6, EX-7, EX-12

  - Test: `examples` workflow, job `argocd-cmp`; `manual:` without the
    seccomp profile in the target, the first local run timed out waiting
    for the Application to become `Healthy`, while PodSecurity rejected
    every pod of the exporter's ReplicaSet
  - Since: #144

## Compile diff

The registry's compile-diff actions compile the base and the merge commit
of a pull request in the consumer sandbox and post the difference of
`compiled/` as one comment (kadet-hub/registry
[`docs/specs/compile-diff.md`](https://github.com/kadet-hub/registry/blob/main/docs/specs/compile-diff.md)).
`first-platform` is a consumer project with its own
`.kapitan-sandbox.yaml`, so this repository runs them on it.
`compile-diff.yml` compiles every pull request that touches
`first-platform/` with read permissions and uploads the diff;
`compile-diff-comment.yml` posts it through `workflow_run`, which GitHub
runs from the default branch only.

- EX-25: A pull request that changes `first-platform/` MUST get one comment
  with the diff of first-platform's `compiled/` between its base and its
  merge commit, edited on every push.

  The pull request that adds the two workflows gets no comment, because the
  comment workflow is not on the default branch yet. Its compile run
  uploads the artifact the comment would show.

  - Test: manual: the `compile-diff` run of the pull request that added this
    uploads a `dev.diff` with the replica change; the comment on the first
    pull request after the merge
  - Since: #143

## Policy checks

`policy-checks/` backs the kadet-hub.org blog post on policy checks of
Kapitan's compiled output in a pull request, compared with the same
policies at admission. One Kapitan project renders podinfo with the
kubernetes generator in two targets. `compliant` pins the image by tag and
digest, sets requests and a memory limit, uses the generator's
`security_profile: restricted` and gets a PodDisruptionBudget.
`noncompliant` uses the tag `latest`, sets no resources, runs the
container privileged and has no PodDisruptionBudget. Its image carries no
digest, unlike EX-3a asks, because nothing pulls it: the cluster sees it
in a server-side dry run only.

The Kyverno policies come from kyverno/policies, which publishes no
release or tag, only a release branch per Kyverno minor version. `check`
downloads the repository's archive at the commit `KYVERNO_POLICIES_COMMIT`,
the head of `release-1.19` when it was pinned, and uses the ValidatingPolicy
versions: `best-practices-vpol/disallow-latest-tag`,
`best-practices-vpol/require-pod-requests-limits` and every policy under
`pod-security-vpol/baseline` and `pod-security-vpol/restricted`, 18 files at
that commit. They ship with `validationActions: [Audit]`. The ClusterPolicy
versions in `best-practices/` and `pod-security/` were not chosen, because
the Kyverno CLI 1.19.2 warns that `kyverno.io/v1 ClusterPolicy is
deprecated and will be removed in a future release`.

Renovate moves the commit along the branch with `datasource=github-digest`
through the `_COMMIT` match string of EX-3, and never to another branch.
The pull request that moves Kyverno to a new minor version has to move the
branch in the comment of the pin. `check` fails until it does, and when the
CLI version the workflow installs differs from the `install.yaml` version
in `check`.

conftest runs `policy/compiled.rego` with `--combine`, so one evaluation
reads every file of a target. One rule requires every image to be pinned
by digest. The other requires, for every Deployment with more than one
replica, a PodDisruptionBudget in its namespace whose selector matches the
Deployment's pod labels, which takes two files at once.

- EX-27: `policy-checks/check` MUST fail unless `kapitan compile` exits 0
  for both targets and logs the generator's warnings for `noncompliant`'s
  tag and resources, and:

  - `kyverno apply` with the policies and `--resource` for every file of
    `compliant` exits 0;
  - the same for `noncompliant` exits non-zero and reports
    `disallow-latest-tag`, `require-requests-limits` and
    `disallow-privileged-containers` for the Deployment `web`, and not
    `restrict-seccomp-strict`;
  - `kyverno apply` with `--resource=compiled` applies the policies to 0
    resources and exits 0;
  - `conftest test --combine` with `policy/` exits 0 for
    `compiled/compliant`, and non-zero for `compiled/noncompliant` with the
    findings for the image digest and the PodDisruptionBudget.

  The CLI counts the violation of a policy in `Audit` as a failure unless
  `--audit-warn` is set. Kyverno derives rules for Deployments and the
  other pod controllers from the Pod policies, so the CLI judges the
  Deployment's pod template. `--resource` reads the files of a directory,
  not those of its subdirectories, and Kapitan writes a target's objects
  into a subdirectory per namespace. `check` therefore names every file.

  `restrict-seccomp-strict` at the pinned commit reads a missing
  `seccompProfile` as `RuntimeDefault`, so it passes `noncompliant`, whose
  pod sets no seccomp profile. The Pod Security Standards' restricted
  profile forbids the absence of a profile. The post says so, and `check`
  fails once the policy changes.

  - Test: `examples` workflow, job `policy-checks`; `manual:` with the
    resources removed from `compliant`, `check` failed on
    `require-requests-limits`, and with `privileged: false` in
    `noncompliant`, it failed because Kyverno no longer reported
    `disallow-privileged-containers`; `manual:` the CLI 1.19.2 printed the
    ClusterPolicy deprecation warning for
    `best-practices/disallow-latest-tag` (2026-11-05); `manual:` Renovate
    44.216.6 (`--platform=local --dry-run=lookup`, 2026-11-05) proposed
    282e77f on `renovate/kyverno-policies-digest` with the policies pin set
    back to 790d5e5, and v1.19.2 and v0.71.1 with the sha256 of their
    linux x86_64 archives with the CLI at v1.19.1 and conftest at v0.71.0
  - Since: #148

- EX-27a: `policy-checks/check` MUST fail unless, in a new kind cluster
  with Kyverno from the `install.yaml` of the CLI's version and the same
  policies:

  - a server-side dry run of `noncompliant`'s Deployment is rejected with
    the three policies of EX-27 once every policy's `validationActions` is
    `[Deny]`, and admitted after the policies are applied again as
    shipped;
  - `compliant`'s objects apply under `[Deny]` and its Deployment becomes
    available (EX-12);
  - `kubectl run --privileged` of `podinfo:latest` is rejected with
    `disallow-privileged-containers`.

  The dry run takes the Deployment through admission without creating it,
  so nothing pulls the `latest` image. Kyverno takes a changed
  `validationActions` within seconds, and `check` repeats the dry run for
  up to a minute until the result changes. The denied run comes first, so
  the admitted one shows Kyverno auditing and not a webhook that is not
  configured yet.

  Not tested: the workflow template `.github/workflows/policy.yml`, which
  needs a repository whose root the consumer workflow compiles; whether the
  consumer workflow's output rules (registry SEC-12) stop `noncompliant` on
  its privileged container before the policy job runs; Kyverno's policy
  reports; Kubernetes' built-in Pod Security Admission.

  Related: EX-4, EX-6, EX-12

  - Test: `examples` workflow, job `policy-checks`
  - Since: #148

## Kapitan refs and External Secrets

`secrets-end-to-end/` backs the kadet-hub.org blog post on which secrets of
an app belong in Kapitan refs and which in External Secrets. Vaultwarden,
from the recipe `vaultwarden`, takes its admin token from Vault through an
ExternalSecret. External Secrets logs in to Vault with an AppRole, and the
AppRole's secret ID is the one secret the inventory carries, as a gpg ref.

The secret ID is a bootstrap secret. External Secrets needs it before it
can read anything from Vault, so it cannot come from Vault through
External Secrets. The admin token is a runtime secret. Whoever runs Vault
changes it, and the change reaches the cluster without a commit or a
compile.

The target `vaultwarden` renders the Secret `vault-approle` with the ref
`?{gpg:vaultwarden/vault-secret-id}` through the kubernetes generator, and
the SecretStore `vault` and the ExternalSecret `vaultwarden` through the
external-secrets generator. The recipe renders a Secret `vaultwarden` with
`ADMIN_TOKEN` from the parameter `applications.vaultwarden.admin_token`.
The target drops that file with the `remove` input, and the ExternalSecret
writes a Secret of the same name with the same key, which the StatefulSet
reads unchanged. The recipe still requires the parameter, so the target
sets a placeholder.

The generators render custom resources only. `check` installs External
Secrets from its release manifest `external-secrets.yaml`, pinned by
version and sha256, as `platform-baseline/check` does. `vault-server.yaml`
stands in for a Vault outside the cluster. It runs Vault's dev server,
which keeps everything in memory, with the root token from a Secret that
`check` creates with a random value, and `-dev-no-store-token`, so the
server writes no token file. Its Service is a ClusterIP Service, and
`check` runs the vault CLI in the server's container with `kubectl exec`.
No Vault address leaves the cluster, and the Vault environment of the
machine that runs `check` plays no part. Vault is licensed BUSL-1.1.

`check` sets up Vault as its admin would. The dev server mounts KV version
2 at `secret/`. The admin token goes to `secret/vaultwarden`, a policy
reads only that path, and the AppRole `vaultwarden` gets the policy and the
role ID `vaultwarden`, which the SecretStore names. Vault issues the secret
ID. `check` writes it with `kapitan refs --write
gpg:vaultwarden/vault-secret-id -t vaultwarden`, which encrypts it for the
recipient the target lists under `kapitan.secrets.gpg.recipients`. The key
is created by `check` in a keyring of its own and exists for one run, so
the ref goes to a temporary refs path. A repository commits `refs/`.

- EX-26: `secrets-end-to-end/check` MUST fail unless the recipe and the
  generators pass the checks of EX-17 and EX-4, and:

  - `kapitan compile` without `--reveal` and with an empty gpg keyring
    succeeds, and its output holds the ref's tag in the Secret
    `vault-approle`, neither the secret ID nor its base64 encoding, and no
    Secret `vaultwarden`;
  - `kapitan refs --reveal` of the Secret `vault-approle` fails with the
    empty keyring;
  - deployed to a new kind cluster with that Secret revealed by the run's
    key, External Secrets reports the SecretStore and the ExternalSecret
    ready and writes the admin token from Vault into the Secret
    `vaultwarden`, and Vaultwarden's admin page accepts that token;
  - after a new token is written to Vault, the Secret holds it within 60
    seconds, the running Vaultwarden still accepts the old token and
    refuses the new one, and after `kubectl rollout restart` it accepts
    the new token and refuses the old one.

  The compile shows for the gpg backend what kapicorp/kapitan#1646 adds
  to Kapitan's documentation. Without `--reveal`, Kapitan reads existing
  ref files and writes their tags, so the compile needs no key. Writing
  the ref needed the recipient's public key, and the reveal needs the
  private key. The other backends are not tested here. #1646 names what
  creating a ref needs for them: a Vault token, or cloud KMS credentials.

  Vaultwarden reads `ADMIN_TOKEN` from its environment, which the kubelet
  sets from the Secret when it starts the container. A changed Secret
  reaches Vaultwarden with the next start only. `check` asserts that the
  old token works until the restart, because the post shows it. Settings
  saved on the admin page go to `config.json` and take precedence over the
  environment, as the recipe's README says. `check` saves none.

  `check` applies the revealed Secret `vault-approle`, the SecretStore and
  the ExternalSecret first and the whole target once the Secret
  `vaultwarden` exists, so that Vaultwarden's pod does not wait for it
  with `CreateContainerConfigError` (EX-6).
  `kapitan refs --reveal` writes the revealed manifests to a pipe into
  `kubectl apply`, not to a file.

  Vaultwarden answers the fourth admin login from one address within 300
  seconds with 429, its defaults `ADMIN_RATELIMIT_MAX_BURST` 3 and
  `ADMIN_RATELIMIT_SECONDS` 300. The counter is kept in memory and starts
  over with the pod. `check` therefore logs in three times before the
  restart and twice after it, and a wrong token is tested as the new token
  before the restart and the old one after it. The first local run logged
  in a fourth time and got 429.

  The token is stored as plain text. Vaultwarden also accepts an Argon2id
  PHC string, which the recipe's README recommends. Not tested: the PHC
  string, Vault's Kubernetes auth method, which needs no secret in the
  inventory, rotating the secret ID, a reveal in Argo CD, ref backends
  other than gpg, and a Vault outside the cluster behind TLS.

  Related: EX-4, EX-6, EX-12, EX-17

  - Test: `examples` workflow, job `secrets-end-to-end`; `manual:` with
    `refresh_interval: 1h` in the target, a local run on 2026-11-05 timed
    out waiting for the new token in the Secret `vaultwarden`
  - Since: #146

## One inventory, three environments, two clusters

`multi-env/` backs the kadet-hub.org blog post on one app in dev, stage
and prod from one Kapitan inventory, with dev and stage on one cluster and
prod on another. The app is the recipe `miniflux`, a feed reader with a
PostgreSQL of its own, pinned in the fetch inventory
`fetch/targets/recipes.yml`. `check` verifies and pulls the recipe and the
generator it pins as `argocd-cmp/check` does.

Each target includes three classes in this order: `common`, one of
`env/dev`, `env/stage` and `env/prod`, and one of `cluster/a` and
`cluster/b`. A later class overrides an earlier one. `common` includes the
recipe and sets what every environment runs, with prod's resources: the
refs, one set per target, `BASE_URL` from the env class's `hostname`, and
the storage class of the database's claim from the cluster class's
`cluster.storage_class`. The env classes set `hostname` and the replicas,
and `env/dev` sets smaller resources. The cluster classes set the cluster's
name and storage class. dev and stage share the cluster `multienv-a`, so the
target `dev` sets the namespace `miniflux-dev`. Apart from that, a target
names its classes and itself.

kind's StorageClass `standard` deletes a volume with its claim.
`storage-class.yaml` stands in for the prod cluster's class `local-retain`,
which keeps it, and `check` applies it to `multienv-b`. The recipe sets no
security context, and PostgreSQL's image starts as root, so the namespaces
enforce the Pod Security level `baseline`.

- EX-28: `multi-env/check` MUST fail unless the recipe and the generator
  pass the checks of EX-17 and EX-4, and, deployed to the kind clusters the
  inventory names, each target runs with these values:

  | Target | Cluster | Namespace | Replicas | Memory limit | Hostname | Storage class |
  |---|---|---|---|---|---|---|
  | dev | `multienv-a` | `miniflux-dev` | 1 | 128Mi | `news.dev.example.com` | `standard` |
  | stage | `multienv-a` | `miniflux` | 2 | 256Mi | `news.stage.example.com` | `standard` |
  | prod | `multienv-b` | `miniflux` | 3 | 256Mi | `news.example.com` | `local-retain` |

  `check` takes each target's cluster and namespace from `kapitan inventory
  --flat`. It reads the memory limit from `memory.max` in the cgroup of
  every miniflux container and the storage class from the database's
  claim. For the hostname it logs in as the admin and reads the Google
  Reader API endpoint from miniflux's page `/integrations`, which miniflux
  builds from `BASE_URL`. The hostnames are under `example.com`, which RFC
  2606 reserves.

  `check` applies PostgreSQL first and waits for it, because miniflux exits
  while it cannot connect. miniflux 2.3.4 runs its migrations without a
  lock (`Migrate` in `internal/database/database.go`). When several
  replicas start on an empty database, one can fail with an error such as
  `pq: column "karakeep_tags" of relation "integrations" already exists`,
  exit and start again on the migrated schema. In three local runs one
  pod of stage and one of prod restarted once. In the first CI run of
  #150 one pod of stage restarted twice and no pod of prod. EX-6 counts
  restarts as broken from the fourth.

  Not tested: an Ingress or Gateway for the hostnames, because kind runs
  no controller that would serve them, and the reclaim of a volume after
  its claim is deleted.

  Related: EX-6, EX-12

  - Test: `examples` workflow, job `multi-env`; `manual:` with
    `hostname: news.prod.example.com` in `env/prod.yml`, the guard
    passed and `check` failed on the API endpoint of prod's miniflux
  - Since: #150

- EX-28a: `multi-env/check` MUST fail unless, in a copy of the project,
  `METRICS_COLLECTOR: 1` under `components.miniflux.env` changes the
  compiled output of dev alone when added to `env/dev.yml`, then of stage
  alone when added to `env/stage.yml`, then of prod alone when added to
  `env/prod.yml`, and moving it from the three env classes into
  `common.yml` changes no compiled file.

  Each step compiles without `--reveal` and compares `compiled/` with the
  step before through `diff -r`, which `check` prints. The registry's
  compile-diff actions show the same difference per target on a pull
  request (EX-25) and are not run on `multi-env`. The value is not
  deployed.

  - Test: `examples` workflow, job `multi-env`
  - Since: #150

- EX-28b: `multi-env/check` MUST fail unless `guard` accepts prod's
  compiled output against stage's, refuses it after the step of EX-28a
  that adds the value to `env/stage.yml` and names the field, and accepts it
  again after the step for `env/prod.yml`.

  `guard` reads the objects of both directories by kind and name and
  compares them field by field. A list item is addressed by its `name` or
  `metadata.name` when every item of its list has one and no two share it.
  Otherwise it is addressed by its index, because two volume mounts of one
  volume would hide each other by name. Two objects of the same kind and name in one directory fail for
  the same reason. Every differing field must be listed in
  `guard-allowed.txt`, otherwise `guard` exits 1. That file allows prod's
  replicas, its `BASE_URL` and the storage class of its database's claim.
  Ref tokens count as equal, because each target has refs of its own and
  the token names the ref's path and hash. An empty directory fails.

  With the guard, stage cannot run ahead of prod in Git: a change to stage
  outside the allowed fields reaches prod in the same commit, and the order
  of the deploys decides which runs first.

  - Test: `examples` workflow, job `multi-env`; `manual:` a Deployment
    with two volume mounts of one volume whose first mount path differs
    between the directories: exit 1 naming `volumeMounts[0].mountPath`
    (exit 0 with the first version of `guard` in #150)
  - Since: #150

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
| `.github/workflows/request-review.yml` | requests `neat-bot` (EX-15) |
| `.github/workflows/compile-diff.yml`, `.github/workflows/compile-diff-comment.yml` | compile diff of `first-platform` on pull requests, pinned to a registry commit (EX-25) |
| `.github/workflows/examples.yml` | One job per example, tool versions, sha256 and images in `env`; job `pins` (EX-3), `advisories` (EX-3f), `ci` (EX-16) |
| `renovate.json` | Org preset for generator pins; regex managers for `# renovate:` comments, inventory charts and images, `==` pins in scripts; package rules that group pins, cert-manager's in `chart-vs-kapitan` included, and leave the rest of its Kapitan side to the chart (EX-3), keep the Python image of `gvisor-ci/run` on 3.13 (EX-3a); release age and the custom datasource `opentofu-provider` (EX-3b) |
| `apiserver-dry-run/.github/workflows/dry-run.yml`, `first-platform/.github/workflows/compile.yml` | Templates shown in the posts; GitHub does not run them here |
| `talos-machine-config/` | One Kapitan project, target `lab` with three Talos nodes; `check` verifies the generator, fills the refs, compiles and runs `talosctl validate` |
| `helm-vs-terraform/providers/.terraform.lock.hcl`, `helm-vs-terraform/terraform-only/.terraform.lock.hcl` | Provider hashes; the first is copied into the compiled root module |
| `argocd-vs-flux/` | One Kapitan project (targets `web`, `argocd`, `flux`), the Gitea manifest and a Chainsaw test per tool; `check <argocd\|flux>` |
| `helm-mutate/` | One Kapitan project (targets `helm`, `podinfo`, `argocd`, `flux`), the podinfo chart pinned in `inventory/classes/podinfo.yml`, the mutations in `inventory/targets/podinfo.yml`, a Chainsaw test per tool; `check <kubectl\|argocd\|flux>` |
| `chart-vs-kapitan/` | One Kapitan project on the omegaconf backend, one target per chart, chart values in `values/`, CRDs and jsonnet libraries fetched by `check` into `kapitan/vendor/`; `check <chart>` (EX-13, EX-13a) |
| `chart-vs-kapitan/kapitan/components/kube-prometheus-stack.jsonnet`, `chart-vs-kapitan/kapitan/jsonnetfile.json`, `chart-vs-kapitan/kapitan/jsonnetfile.lock.json` | Rules and dashboards of kube-prometheus-stack and the pins of their sources (EX-13a) |
| `kubevirt-csi/` | One Kapitan project (targets `infra`, `tenant`) with the kubevirt generator pinned in `inventory/classes/generators.yml`, `infra.yaml`, the tenant workload in `tests/pvc.yaml`, the negative case's claim in `tests/static-pvc.yaml`; `check` (EX-14, EX-14a) |
| `open-webui-searxng/` | One Kapitan project (targets `open-webui`, `searxng`) on the omegaconf backend, `open-webui` and `searxng` pinned in the fetch inventory `fetch/targets/recipes.yml`, the recipes they include taken from the index; `check` (EX-17) |
| `platform-baseline/` | One Kapitan project on the omegaconf backend (targets `cert-manager`, `kyverno`, `monitoring`, `external-secrets`, `velero`, `argocd`, `podinfo`), the shared class `inventory/classes/platform.yml`, the cert-manager recipe pinned in `fetch/targets/recipes.yml`, the stand-ins `git-server.yaml` and `s3-server.yaml`; `check` (EX-18, EX-18a) |
| `immich-cnpg/` | One Kapitan project (targets `cnpg`, `immich`) on the omegaconf backend, the four recipes pinned in the fetch inventory `fetch/targets/recipes.yml`; `check` (EX-19) |
| `pihole-powerdns/` | One Kapitan project (targets `dns`, `pihole`) on the omegaconf backend, the zone in `inventory/classes/home.yml`, the three recipes pinned in the fetch inventory `fetch/targets/recipes.yml`; `check` (EX-20) |
| `helmfile-vs-kapitan/` | `helmfile/` (releases, environments, values templates) and `kapitan/` (targets `dev`, `prod`, classes `common`, `podinfo`, `valkey`), both pinning podinfo and Valkey; `check` (EX-21) |
| `timoni-vs-kapitan/` | The Timoni module `timoni/app` with its vendored Kubernetes schemas, the bundle `timoni/shop.cue` with `dev.cue` and `prod.cue`, the Kapitan project of `config-tools`; `check` (EX-22 to EX-22b) |
| `kcl-vs-kapitan/` | The KCL module `kcl/` (`app/app.k`, `shop.k`, `dev.k`, `prod.k`, `kcl.mod`, `kcl.mod.lock`), the Kapitan project of `config-tools`; `check` (EX-23 to EX-23b) |
| `argocd-cmp/` | One Kapitan project (target `blackbox-exporter`) on the omegaconf backend, the recipe pinned in the fetch inventory `fetch/targets/recipes.yml`, the plugin's ConfigMap `kapitan-plugin.yaml`, the sidecar in `repo-server-patch.yaml`, the egress policy `repo-server-egress.yaml`, `application.yaml`, `git-server.yaml`; `check` (EX-24) |
| `policy-checks/` | One Kapitan project (targets `compliant`, `noncompliant`) with the kubernetes generator pinned in `inventory/classes/web.yml`, the conftest rules in `policy/compiled.rego`, the pull request workflow template `.github/workflows/policy.yml`; `check` (EX-27, EX-27a) |
| `secrets-end-to-end/` | One Kapitan project (target `vaultwarden`) on the omegaconf backend, the recipe pinned in the fetch inventory `fetch/targets/recipes.yml`, the gpg recipient, the Secret with the ref, the SecretStore and the ExternalSecret in the target, the Vault dev server `vault-server.yaml`; `check` (EX-26) |
| `multi-env/` | One Kapitan project on the omegaconf backend (targets `dev`, `stage`, `prod`; classes `common`, `env/*`, `cluster/*`), the recipe pinned in the fetch inventory `fetch/targets/recipes.yml`, `guard` with `guard-allowed.txt`, `storage-class.yaml`; `check` (EX-28 to EX-28b) |
| `cert-manager-mutate/` | One Kapitan project (targets `helm`, `cert-manager`, `trust-manager`), the charts pinned in `inventory/classes/`, the mutations in the two targets, `internal-ca.yaml`, `bundle.yaml`, one Chainsaw test; `check` |
