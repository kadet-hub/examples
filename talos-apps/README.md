# talos-apps

Talos machine configs for a control plane node and a worker, and the app
that runs on the cluster, from one Kapitan inventory. The app is the
published kadet-hub recipe `blackbox-exporter`, with an egress
NetworkPolicy built from the same networks Talos gets. Written up at
https://kadet-hub.org/blog/talos-homelab-kapitan/.

| Path | Content |
|---|---|
| `inventory/classes/cluster.yml` | The networks both targets read: nodes `192.0.2.0/24`, pods `10.244.0.0/16`, Services `10.96.0.0/12` |
| `inventory/classes/talos/` | `cluster.yml` with what every node shares, `nodes.yml` with role, hostname and address per node, `secrets.yml` with the cluster secrets as Kapitan refs |
| `inventory/classes/generators.yml` | The talos generator by version and digest; the kubernetes generator comes with the recipe |
| `inventory/targets/talos.yml` | Machine configs for `cp-1` and `worker-1` |
| `inventory/targets/blackbox-exporter.yml` | The recipe, its Namespace with the Pod Security level `restricted`, the module `tcp_connect` and the egress NetworkPolicy |
| `fetch/targets/recipes.yml` | The recipe by version and digest, in the fetch inventory format of the registry's [consumer docs](https://github.com/kadet-hub/registry/blob/main/docs/consumers.md#recipes) |
| `.kapitan` | The omegaconf inventory backend, which the recipe is written for |

Addresses from 192.0.2.0/24 are reserved for documentation. The pod and
Service networks are Talos' defaults.

## Running

```sh
# on a Linux Docker host, with gh (logged in), jq, oras, uv, talosctl,
# kubectl and docker on PATH
sudo modprobe br_netfilter
./check
```

`check` verifies the latest signed index and the attestation of the recipe,
of the kubernetes generator it pins and of the talos generator, and pulls
them by digest into `inventory/classes/recipes/` and `lib/`. It creates the
cluster secrets with `talosctl gen secrets`, writes them to refs and
compiles both targets. Every machine config has to pass `talosctl validate`
in the modes `metal` and `container`. A second compile with another pod
CIDR in `cluster.yml` has to change both machine configs and the
NetworkPolicy and nothing else, and `check` prints that diff.

It then starts one Talos container per node in a Docker network with the
node network of the inventory, the way `talosctl cluster create docker`
runs Talos, but with the compiled configs. It bootstraps the cluster,
waits for both nodes and checks that their addresses, their pod CIDRs and
the Service `kubernetes` lie in the networks of `cluster.yml`. It deploys
the exporter without its NetworkPolicy, probes the control plane endpoint,
the Service `kubernetes`, a CoreDNS pod and `https://github.com/`, applies
the policy and probes again. Only the last target may answer then. Last,
it applies the policy from the compile with another pod CIDR, which no
longer covers the cluster's pods, and the CoreDNS pod has to answer again.
`KEEP=1 ./check` keeps the containers `talosapps-talos-apps-cp-1` and
`talosapps-talos-apps-worker-1` and prints the path of the kubeconfig and
talosconfig.

Flannel, Talos' CNI, needs the kernel module `br_netfilter` on the Docker
host. Without it, a pod gets no answer from a Service whose pod runs on
the same node, and `check` stops at once.

## Using it on hardware

The configs pass `talosctl validate --mode metal` and install to
`/dev/sda` with Talos' metal installer. They set no nameserver and no NTP
server, so that the same files boot in Docker, and Talos falls back to its
defaults on hardware. Add `nameservers` and `time.servers` to
`inventory/classes/talos/cluster.yml` for your network.

The base64 backend only encodes. Keep the refs in one of Kapitan's
encrypting backends, such as gpg or Vault, and compile with `--reveal`
only where the configs are applied.
