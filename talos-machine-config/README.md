# talos-machine-config

Talos machine configs for one control plane node and two workers, rendered
from one Kapitan inventory and checked with `talosctl validate`. Written up
at https://kadet-hub.org/guides/talos-machine-config/.

[Kapitan](https://kapitan.dev/) renders config files from a YAML inventory.
A target lists classes, Kapitan merges their parameters into one tree, and a
generator turns that tree into files. This example uses the
[talos generator](https://kadet-hub.org/generators/talos/) from kadet-hub, a
registry of Kapitan generators published as signed OCI artifacts.

The target `inventory/targets/lab.yml` lists these classes:

| Class | Sets |
|---|---|
| `generators` | The talos generator, pinned by version and digest |
| `talos.secrets` | The cluster secrets as Kapitan refs, see [Secrets](#secrets) |
| `talos.cluster` | What every node shares: cluster name `lab`, control plane endpoint `https://192.0.2.11:6443`, static address on `eth0` with a default route via 192.0.2.1, nameserver 192.0.2.53, NTP server `time.example.com`, install disk `/dev/sda` |
| `talos.nodes` | Per node: role, hostname and address. `cp-1` is the control plane, `worker-1` and `worker-2` are workers |
| `talos.patches.worker-1-nvme` | Install disk `/dev/nvme0n1` for worker-1 only, where you would otherwise apply a config patch to one node |

Addresses from 192.0.2.0/24 and `time.example.com` are reserved for
documentation.

Kapitan writes `compiled/lab/talos/cp-1.yaml`, `worker-1.yaml` and
`worker-2.yaml`. Each file holds a v1alpha1 document followed by typed
documents such as HostnameConfig, LinkConfig, ResolverConfig,
TimeSyncConfig and UnattendedInstallConfig. The generator picks the secrets
per role. `cp-1.yaml` carries the machine, cluster, etcd and aggregator CAs
with their keys, the service account key and the secretbox encryption
secret. The worker files get the machine and cluster CA certificates, the
machine and bootstrap tokens and the cluster discovery ID and secret.

## Running

```sh
# gh (logged in), jq, oras, uv and talosctl on PATH
./check
```

`check` downloads the latest signed kadet-hub index and verifies it and the
generator with `gh attestation verify`. It stops unless the index lists the
pinned generator version, not yanked, with the pinned digest. It then pulls
the generator by digest with `oras`. uv installs the Python and Kapitan
versions pinned in `check`. The [examples workflow](../.github/workflows/examples.yml)
pins talosctl, oras and uv by version and sha256.

`check` exits 0 only if

- every node config passes `talosctl validate --mode metal`,
- the nameserver and NTP server from `talos.cluster` appear in all three
  configs,
- removing `talos.patches.worker-1-nvme` from the target changes
  `worker-1.yaml` and no other file,
- an endpoint without scheme (`192.0.2.11:6443`) compiles but fails
  `talosctl validate`.

`talosctl validate` reads one file and contacts no machine. It decodes every
document and checks field values, for example that the control plane
endpoint is a URL with scheme and that the cluster CA document holds a
parseable certificate. It accepts an endpoint that is not cp-1's address,
an install disk or link name the machine does not have, and a worker that
trusts a different cluster CA than cp-1. Beyond that, `check` tests only the
nameserver, the NTP server and what the patch changes.

## Secrets

No secret is committed. `talos.secrets` sets each secret to a Kapitan ref
such as `?{base64:talos/machine-ca-crt}`, which Kapitan replaces with the
content of `refs/talos/machine-ca-crt` when it compiles with `--reveal`.

On every run `check` deletes `lib/`, `compiled/` and `refs/` and creates a
fresh bundle with `talosctl gen secrets` in a temporary directory. It writes
each value of the bundle to its own ref with
`kapitan refs --write base64:talos/<name>` and compiles with `--reveal`,
because an unrevealed ref fails `talosctl validate` as invalid base64. The
configs in `compiled/` therefore hold the secrets in plain text, and the
secrets change on every run. `refs/` and `compiled/` are in `.gitignore`.

The base64 backend only encodes. A real cluster would keep these refs in
one of Kapitan's encrypting backends, such as gpg or Vault.
