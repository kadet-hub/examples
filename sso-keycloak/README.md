# sso-keycloak

Single sign-on with Keycloak for Gitea, Open WebUI and Miniflux, from the
published kadet-hub recipes `keycloak`, `keycloak-operator`, `gitea`,
`open-webui` and `miniflux`, with `cert-manager` and `cnpg` as operators.
Written up at https://kadet-hub.org/blog/keycloak-sso-self-hosted-apps/.

| Path | Content |
|---|---|
| `fetch/targets/recipes.yml` | The seven recipes the targets include, by version and digest, in the fetch inventory format of the registry's [consumer docs](https://github.com/kadet-hub/registry/blob/main/docs/consumers.md#recipes). The recipes they include, `postgresql`, `valkey` and `ollama`, come from the index |
| `inventory/classes/sso.yml` | The issuer and, per app, client ID, URL, redirect URI, client secret and admitted group, read by Keycloak and the app |
| `inventory/targets/keycloak.yml` | Keycloak in namespace `keycloak`, with the realm `home`, its users, groups and clients as a KeycloakRealmImport, and the CA Issuer of its certificate |
| `inventory/targets/gitea.yml`, `open-webui.yml`, `miniflux.yml` | Each app in its namespace, with Keycloak as OIDC provider |
| `inventory/targets/cert-manager.yml`, `cnpg.yml`, `keycloak-operator.yml` | The operators, each in its namespace |
| `.kapitan` | The omegaconf inventory backend, which the recipes are written for |

## Running

```sh
# gh (logged in), jq, oras, uv, kind, kubectl, curl, openssl and docker on PATH
./check
```

`check` verifies the latest signed index and the attestation of every
recipe and generator and pulls them by digest into
`inventory/classes/recipes/` and `lib/`. It creates a CA with openssl and
writes it to refs with the base64 backend in a temporary refs path, where
the first compile adds the client secrets and passwords with random
values. It compiles the targets, and once more with Gitea moved to another
URL in `inventory/classes/sso.yml` to show that only the realm import and
Gitea's `ROOT_URL` change. It then deploys everything to a new kind
cluster, points `sso.example.test` at Keycloak's Service in CoreDNS and
signs in with curl as a browser: `alice` to all three apps with one
password, a wrong password to none, `bob` to Miniflux only. Last, it points
Miniflux at Keycloak's in-cluster name, which fails on the issuer.
`KEEP=1 ./check` keeps the cluster `sso-keycloak`.
