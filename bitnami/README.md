# PostgreSQL without the Bitnami chart

Companion to the post "Bitnami Helm alternatives: render manifests yourself" on the [kadet-hub blog](https://kadet-hub.org/blog/bitnami/).

`inventory/targets/app-db.yml` describes one CloudNativePG Cluster. `run.sh`
verifies the index and the [cloudnative-pg](https://kadet-hub.org/generators/cloudnative-pg/)
generator with `gh attestation verify`, pulls the generator by digest with
`oras`, compiles with Kapitan 0.36.3 and validates the output with
kubeconform against the CRD schemas the generator ships. The result is
written to `compiled/`.

```sh
./run.sh
```

Needs `gh` (logged in), `oras`, `jq`, `uv` and `kubeconform` on `PATH`.
The CloudNativePG operator 1.30.1 must already run in the cluster you
apply the output to; this example renders the Cluster, not the operator
and not the PostgreSQL image.
