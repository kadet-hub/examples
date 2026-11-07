# matrix-federation

Two Matrix homeservers, `a.example.test` and `b.example.test`, from the
published recipe [matrix-synapse](https://kadet-hub.org/recipes/matrix-synapse/)
with its option `federation`, on one kind cluster. `check` proves that they
federate: the admin of `a.example.test` joins a room of `b.example.test` by
its alias, and each admin reads the other's message. It also proves that the
join fails without the option on `b.example.test` (404) and without
`ip_range_whitelist` on `a.example.test` (502).

```sh
matrix-federation/check
```

Needs `gh` (logged in), `jq`, `oras`, `uv`, `kind`, `kubectl`, `chainsaw`,
`curl`, `openssl` and `docker`. `KEEP=1` keeps the cluster.

## What a target needs for federation

The option serves the federation API and `/.well-known/matrix/server`, which
sends other servers to port 443 of the server name. Synapse's federation
client speaks TLS only, so something in front of Synapse terminates TLS on
port 443 for the name. Here that is the nginx `matrix-tls` of the class
[`federated`](inventory/classes/federated.yml), with a certificate that
`check` signs with its own CA. A real deployment uses its ingress and a
public certificate.

Two settings in the class are there because both servers run in one
cluster:

- `federation_custom_ca_list` trusts `check`'s CA, which signed both
  certificates.
- `ip_range_whitelist: [10.96.0.0/12]` lets Synapse connect to kind's
  Service addresses. Synapse drops every address of a private range
  (`ip_range_blacklist`) when it resolves another server.

kind's CoreDNS resolves each server name to its proxy's Service, which a
public DNS record does for a real server.

## Layout

| Path | Content |
|---|---|
| `fetch/targets/recipes.yml` | `cnpg` and `matrix-synapse`, by version and digest. `postgresql`, which `matrix-synapse` includes, comes at the digest of its index record. |
| `inventory/targets/` | `cnpg`, the operator; `synapse-a` and `synapse-b`, the two servers |
| `inventory/classes/federated.yml` | server name and refs from `federated.name`, the TLS proxy and Synapse's settings for kind |
| `tests/chainsaw-test.yaml`, `tests/namespaces.yaml` | the deploy, step by step, and the namespaces at Pod Security `restricted` |
| `tests/federate.sh` | the join, the messages and the two failing joins |

The spec is EX-33 and EX-33a in
[docs/specs/examples.md](../docs/specs/examples.md).
