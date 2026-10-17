# apiserver-dry-run

Server-side dry run of every manifest against etcd and kube-apiserver
v1.37.1 on 127.0.0.1, without a cluster. Written up at
https://kadet-hub.org/blog/apiserver-dry-run/.

```sh
# etcd, kube-apiserver, kubectl, openssl and curl on PATH
./dry-run crds manifests
```

`manifests/broken-*.yaml` pass `kubeconform -strict` with the CRD schemas and
are rejected by the API server, so the job in
`.github/workflows/dry-run.yml` fails on purpose. Delete them to see it pass.
`./check` runs both kubeconform and `./dry-run` and passes only while that
is true.

`crds/gateway-api-v1.6.3-standard-install.yaml` is
https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.3/standard-install.yaml,
sha256 `356c2b8e286a964dc20995435659ad1095386329974793af10bbfe3eff977fe5`.
