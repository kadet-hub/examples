# chart-vs-kapitan

Widely used Helm charts rebuilt as one Kapitan project on the omegaconf
backend, rendered by kadet-hub generators. Each target in
`kapitan/inventory/targets/` stands for the chart of the same name, with
the chart's values in `values/`.

`./check <chart>` renders both sides, has a kind cluster's API server
default them, and fails unless they are equal outside RBAC, grant the same
permissions and the Kapitan side works on its own cluster. kube-prometheus-stack
is compared by what both sides do on their own kind cluster instead. It
prints the lines each side asks you to maintain. What is compared and what
is normalized is in [docs/specs/examples.md](../docs/specs/examples.md)
(EX-13, EX-13a).

| Chart | Version | Kapitan side works when |
|---|---|---|
| metrics-server | 3.14.0 | `kubectl top nodes` answers |
| cert-manager | v1.21.2 | a self-signed ClusterIssuer issues a Certificate |
| kube-prometheus-stack | 92.11.0 | Prometheus scrapes the same jobs with the same health and loads the same rules, Alertmanager is ready, Grafana has the same datasources and dashboards as the chart's |

The rules and dashboards of kube-prometheus-stack are not copied from the
chart. `kapitan/components/kube-prometheus-stack.jsonnet` compiles them
from the upstream sources the chart syncs from, pinned in
`kapitan/jsonnetfile.json` and `kapitan/jsonnetfile.lock.json`; `check`
vendors them with `jb install`.
