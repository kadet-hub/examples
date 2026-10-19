#!/usr/bin/env bash
# Verify, fetch, compile and validate. Needs gh, oras, jq, uv and kubeconform.
set -euo pipefail
cd "$(dirname "$0")"

name=cloudnative-pg
read -r version digest < <(sed -nE "s|^ *source: ghcr\.io/kadet-hub/$name:([^@]+)@(sha256:[0-9a-f]{64})$|\1 \2|p" inventory/targets/app-db.yml)
identity=https://github.com/kadet-hub/registry/.github/workflows/release.yml@refs/heads/main

# 1. The index lists this digest under the version the tag names, and is not yanked.
index=$(oras resolve ghcr.io/kadet-hub/index:latest)
gh attestation verify "oci://ghcr.io/kadet-hub/index@$index" --owner kadet-hub --cert-identity "$identity"
rm -rf .index && oras pull -o .index "ghcr.io/kadet-hub/index@$index"
jq -e --arg v "$version" --arg d "$digest" '.generators["cloudnative-pg"][$v] | .digest == $d and .yanked == null' .index/index.json

# 2. The artifact was built by the marketplace release workflow.
gh attestation verify "oci://ghcr.io/kadet-hub/$name@$digest" --owner kadet-hub --cert-identity "$identity"

# 3. Pull by digest and unpack where the inventory expects it.
rm -rf .oci lib/$name && mkdir -p lib/$name
oras pull -o .oci "ghcr.io/kadet-hub/$name@$digest"
tar -xf .oci/$name.tar -C lib/$name

# 4. Compile without --fetch: the dependency is already in place.
# Kapitan 0.36.3 needs omegaconf 2.4.0.dev4; newer releases drop ListMergeMode.
uvx --python 3.13 --from 'kapitan[omegaconf,reclass-rs]==0.36.3' --with omegaconf==2.4.0.dev4 kapitan compile --inventory-backend omegaconf

# 5. Validate against the schemas the generator ships.
kubeconform -strict -summary \
  -schema-location "lib/$name/schemas/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
  compiled/
