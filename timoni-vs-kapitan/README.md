# timoni-vs-kapitan

The app of [same-app](../same-app/) rendered with Timoni and with Kapitan.
Written up at https://kadet-hub.org/blog/timoni-vs-kapitan/.

| Path | Content |
|---|---|
| `timoni/app/` | The Timoni module: the values schema in `templates/config.cue`, one template per kind, and the Kubernetes 1.37 API schemas that `timoni mod vendor k8s -v 1.37` wrote to `cue.mod/gen` |
| `timoni/shop.cue` | The bundle: instances `web` and `api`, the module by registry URL and version, the values both environments share |
| `timoni/dev.cue`, `timoni/prod.cue` | The values per environment |
| `kapitan/` | The inventory of [config-tools](../config-tools/), with the kadet-hub kubernetes generator pinned by digest in `inventory/classes/common.yml` |

The bundle names the module as `oci://localhost:5001/modules/app` at
version 1.0.0. `check` starts a registry there, pushes `timoni/app` with
`timoni mod push` and adds the digest of that push to the bundle. Without
a registry that serves the module there, the bundle does not build.

## Running

```sh
# timoni, docker, curl, jq and uv on PATH; gh (logged in) and oras for the generator
./check
```
