# pihole-powerdns

DNS for a home or office network from the published kadet-hub recipes
`pihole`, `external-dns-powerdns` and `powerdns`. PowerDNS is
authoritative for the zone `home.example`. external-dns writes a record
into it for every annotated Service. Pi-hole is the resolver the clients
ask, and it forwards the zone to PowerDNS. Written up at
https://kadet-hub.org/blog/pihole-powerdns-kubernetes/.

| Path | Content |
|---|---|
| `fetch/targets/recipes.yml` | The three recipes by version and digest, in the fetch inventory format of the registry's [consumer docs](https://github.com/kadet-hub/registry/blob/main/docs/consumers.md#recipes) |
| `inventory/classes/home.yml` | The zone, read by both targets |
| `inventory/targets/dns.yml` | PowerDNS and external-dns in namespace `dns` |
| `inventory/targets/pihole.yml` | Pi-hole in namespace `pihole`, with the zone forwarded to PowerDNS and its Service annotated for external-dns |
| `.kapitan` | The omegaconf inventory backend, which the recipes are written for |

external-dns-powerdns 1.0.0 includes powerdns 1.0.0, so the fetch
inventory pins that version and not powerdns 1.0.1.

## Running

```sh
# gh (logged in), jq, oras, uv, kind, kubectl and docker on PATH
./check
```

`check` verifies the latest signed index and the attestation of every
recipe and generator, pulls them by digest into
`inventory/classes/recipes/` and `lib/`, and compiles both targets. The
API key and the password are refs with the base64 backend in a temporary
refs path, so every run gets new random values. It deploys `dns` and then
`pihole` to a new kind cluster and queries Pi-hole with `dig` from a
client pod. `pihole.home.example` must resolve to the cluster IP of the
Service `pihole`, which external-dns wrote into PowerDNS.
`missing.home.example` must get NXDOMAIN with the zone's SOA from
PowerDNS. `ads.example` must get NXDOMAIN, and `0.0.0.0` once the check
has denied it through Pi-hole's API.
`KEEP=1 ./check` keeps the cluster `dnsstack-pihole-powerdns`.

## Wiring

Pi-hole forwards the zone through
`FTLCONF_misc_dnsmasq_lines: server=/home.example/powerdns.dns.svc.cluster.local`.
FTL's dnsmasq resolves the Service name once, when FTL starts. Deploy
`dns` first, and restart Pi-hole when the Service `powerdns` is recreated.

On a LAN, set `FTLCONF_dns_upstreams` to the resolvers Pi-hole should ask
and expose the Service `pihole` to the clients, for example with
`components.pihole.service.type: LoadBalancer`. external-dns then writes
the load balancer's address for `pihole.home.example`. Neither is tested
here, because kind has no load balancer.
