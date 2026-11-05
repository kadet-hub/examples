# kcl-vs-kapitan

The app of [same-app](../same-app/) rendered with KCL and with Kapitan.
Written up at https://kadet-hub.org/blog/kcl-vs-kapitan/.

| Path | Content |
|---|---|
| `kcl/app/app.k` | The schema `App` and the function that renders its objects with the schemas of the `k8s` module |
| `kcl/shop.k` | Apps `web` and `api` with the values both environments share; prints the objects as a YAML stream |
| `kcl/dev.k`, `kcl/prod.k` | The values per environment, merged into `web` and `api` |
| `kcl/kcl.mod`, `kcl/kcl.mod.lock` | The `k8s` module 1.36 from `ghcr.io/kcl-lang/k8s`, and its checksum |
| `kapitan/` | The inventory of [config-tools](../config-tools/), with the kadet-hub kubernetes generator pinned by digest in `inventory/classes/common.yml` |

`kcl run shop.k prod.k` in `kcl/` prints the prod manifests.

## Running

```sh
# kcl and uv on PATH; gh (logged in) and oras for the generator
./check
```
