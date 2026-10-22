# chart-vs-kapitan

Widely used Helm charts rebuilt as one Kapitan project on the omegaconf
backend, rendered by the kadet-hub `kubernetes` generator. Each target in
`kapitan/inventory/targets/` stands for the chart of the same name, with
the chart's values in `values/`.

`./check <chart>` renders both sides, has a kind cluster's API server
default them, and fails unless they are equal outside RBAC, grant the same
permissions and the Kapitan side works on its own cluster. It prints the
lines each side asks you to maintain. What is compared and what is
normalized is in [docs/specs/examples.md](../docs/specs/examples.md)
(EX-13).

| Chart | Version | Kapitan side works when |
|---|---|---|
| metrics-server | 3.14.0 | `kubectl top nodes` answers |
| cert-manager | v1.21.2 | a self-signed ClusterIssuer issues a Certificate |
