# sso-keycloak

Single sign-on with Keycloak for Gitea, Open WebUI, Miniflux, Mattermost
and Synapse, from the published kadet-hub recipes `keycloak`,
`keycloak-operator`, `gitea`, `open-webui`, `miniflux`, `mattermost` and
`matrix-synapse`, with `cert-manager` and `cnpg` as operators. The first
three apps are written up at
https://kadet-hub.org/blog/keycloak-sso-self-hosted-apps/.

| Path | Content |
|---|---|
| `fetch/targets/recipes.yml` | The nine recipes the targets include, by version and digest, in the fetch inventory format of the registry's [consumer docs](https://github.com/kadet-hub/registry/blob/main/docs/consumers.md#recipes). The recipes they include, `postgresql`, `valkey` and `ollama`, come from the index |
| `inventory/classes/sso.yml` | The issuer and, per app, client ID, URL, redirect URI, client secret and admitted group, read by Keycloak and the app |
| `inventory/targets/keycloak.yml` | Keycloak in namespace `keycloak`, with the realm `home`, its users, groups, clients and the client scope `openid` as a KeycloakRealmImport, and the CA Issuer of its certificate |
| `inventory/targets/gitea.yml`, `open-webui.yml`, `miniflux.yml`, `matrix-synapse.yml` | Each app in its namespace, with Keycloak as OIDC provider, Synapse over HTTPS |
| `inventory/targets/mattermost.yml` | Mattermost Team Edition in namespace `mattermost`, with Keycloak's endpoints in place of GitLab's for its GitLab login |
| `inventory/targets/cert-manager.yml`, `cnpg.yml`, `keycloak-operator.yml` | The operators, each in its namespace |
| `.kapitan` | The omegaconf inventory backend, which the recipes are written for |
| `tests/chainsaw-test.yaml`, `tests/namespaces.yaml` | The deploy to kind in the order Keycloak and the apps need, with a wait after each step |
| `tests/login.py` | The logins in Playwright's headless Chromium |

## Running

```sh
# gh (logged in), jq, oras, uv, kind, kubectl, chainsaw, certutil, openssl and docker on PATH
./check
```

`check` verifies the latest signed index and the attestation of every
recipe and generator and pulls them by digest into
`inventory/classes/recipes/` and `lib/`. It creates a CA with openssl and
writes it and a certificate for Synapse to refs with the base64 backend in
a temporary refs path, where the first compile adds the client secrets and
passwords with random values. It compiles the targets, and once more with Gitea moved to another
URL in `inventory/classes/sso.yml` to show that only the realm import and
Gitea's `ROOT_URL` change. It then creates a kind cluster, where the
Chainsaw test points `sso.example.test` at Keycloak's Service in CoreDNS
and deploys everything. `tests/login.py` signs in with the headless
Chromium of the pinned Playwright image: `alice` to all five apps with
one password, a wrong password to none, `bob` to Miniflux and Mattermost
only. For Synapse it trades the login token for an access token and calls
`/whoami` with it. Last, it points Miniflux at Keycloak's in-cluster name,
which fails on the issuer. `KEEP=1 ./check` keeps the cluster
`sso-keycloak`.

## Not proven

- A group restriction for Mattermost. Team Edition's GitLab login has
  none, so `bob` gets in.
- A user without `mattermost_id`, and setting the attribute after the
  import. Keycloak's admin console does not show it with the default user
  profile.
- A browser at Synapse over plain HTTP. Synapse sets its login cookie
  `Secure`, so the login needs HTTPS, which is read from Synapse's code.

The other gaps are listed under EX-32 to EX-32c in
[docs/specs/examples.md](../docs/specs/examples.md).
