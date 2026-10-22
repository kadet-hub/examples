// The PrometheusRules and dashboard ConfigMaps of kube-prometheus-stack, built
// from the sources the chart's hack/sync_prometheus_rules.py and
// hack/sync_grafana_dashboards.py read, with their settings and the edits they
// make at the chart's default values. ../jsonnetfile.json pins the sources.
local p = (import 'lib/kapitan.libjsonnet').inventory().parameters;

local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+: { namespace: p.namespace },
    kubernetesControlPlane+: { kubeProxy: true },
  },
};
local etcd = import 'github.com/etcd-io/etcd/contrib/mixin/mixin.libsonnet';
local etcdRules = { prometheusAlerts+:: {}, prometheusRules+:: {} } + etcd + {
  _config: {
    etcd_selector: 'job=~".*etcd.*"',
    etcd_instance_labels: 'instance, pod',
    scrape_interval_seconds: 30,
    clusterLabel: 'job',
  },
};

// The dashboards the chart leaves out at its default values.
local skipDashboards = [
  'k8s-resources-windows-cluster',
  'k8s-resources-windows-namespace',
  'k8s-resources-windows-pod',
  'k8s-windows-cluster-rsrc-use',
  'k8s-windows-node-rsrc-use',
  'prometheus-remote-write',
];

local mapStrings(f, x) =
  if std.isString(x) then f(x)
  else if std.isArray(x) then [mapStrings(f, e) for e in x]
  else if std.isObject(x) then { [k]: mapStrings(f, x[k]) for k in std.objectFields(x) }
  else x;

// sync_prometheus_rules.py: its replacement_map, and the space it puts between
// by or on and the parenthesis, also at the start of a string.
local ruleEdits(group) =
  [
    ['job="prometheus-operator"', 'job="%s-operator"' % p.release],
    ['job="prometheus-k8s"', 'job="%s-prometheus"' % p.release],
    ['job="alertmanager-main"', 'job="%s-alertmanager"' % p.release],
    ['(namespace,service)', '(namespace,service,cluster)'],
  ]
  + (if group == 'kubernetes-apps' then [['job="kube-state-metrics"', 'job="kube-state-metrics", namespace=~".*"']] else [])
  + (if group == 'kubernetes-storage' then [['job="kubelet", metrics_path="/metrics', 'job="kubelet", namespace=~".*", metrics_path="/metrics']] else [])
  + [[ws + kw + '(', ws + kw + ' ('] for ws in [' ', '\n'] for kw in ['by', 'BY', 'on', 'ON']];
local edit(group) = function(s)
  local t = std.foldl(function(acc, e) std.strReplace(acc, e[0], e[1]), ruleEdits(group), ' ' + s);
  std.substr(t, 1, std.length(t) - 1);

// sync_prometheus_rules.py: add_custom_annotations_etcd_runbook_urls
local etcdRunbook(rule) =
  if std.objectHas(rule, 'alert') then
    rule { annotations+: { runbook_url: 'https://runbooks.prometheus-operator.dev/runbooks/etcd/' + std.asciiLower(rule.alert) } }
  else rule;

// sync_prometheus_rules.py takes the rules of every component but Grafana.
local groups =
  std.flattenArrays([
    kp[component][resource].spec.groups
    for component in std.objectFields(kp)
    if component != 'grafana'
    for resource in std.objectFields(kp[component])
    if std.get(kp[component][resource], 'kind') == 'PrometheusRule'
  ])
  + (etcdRules.prometheusAlerts + etcdRules.prometheusRules).groups;

// sync_prometheus_rules.py: fix_expr strips trailing whitespace
local rules(group) =
  local edited = mapStrings(edit(group.name), group {
    rules: [r { expr: std.rstripChars(r.expr, ' \n') } for r in group.rules],
  });
  if group.name == 'etcd' then edited { rules: std.map(etcdRunbook, edited.rules) } else edited;

// sync_grafana_dashboards.py: patch_dashboards_json, and the timezone, editable
// and interval it sets from the chart's values.
local patchDashboard(d) =
  local walk(x) =
    if std.isArray(x) then [walk(e) for e in x]
    else if std.isObject(x) then {
      [k]:
        if k == 'timezone' && std.isString(x[k]) then 'utc'
        else if k == 'editable' && std.isBoolean(x[k]) then true
        else if k == 'interval' && std.isString(x[k]) then '1m'
        else walk(x[k])
      for k in std.objectFields(x)
    }
    else if std.isString(x) then std.strReplace(x, 'job="prometheus-k8s",namespace="monitoring"', '')
    else x;
  walk(d) + {
    templating+: {
      list: [if v.name == 'cluster' then v { allValue: '.*', hide: 2 } else v for v in super.list],
    },
  };

local dashboards =
  { [std.strReplace(f, '.json', '')]: kp.values.grafana.dashboards[f] for f in std.objectFields(kp.values.grafana.dashboards) }
  + { [std.strReplace(f, '.json', '')]: etcd.grafanaDashboards[f] for f in std.objectFields(etcd.grafanaDashboards) }
  + { 'k8s-coredns': import 'github.com/prometheus-community/helm-charts/charts/kube-prometheus-stack/files/dashboards/k8s-coredns.json' };

local name(n) = std.rstripChars(std.substr('%s-%s' % [p.release, std.asciiLower(std.strReplace(n, '_', '-'))], 0, 63), '-');

{
  ['%s/%s-promrule' % [p.namespace, name(g.name)]]: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: { name: name(g.name), namespace: p.namespace, labels: { release: p.release } },
    spec: { groups: [rules(g)] },
  }
  for g in groups
} + {
  ['%s/%s-dashboard' % [p.namespace, name(d)]]: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: { name: name(d), namespace: p.namespace, labels: { grafana_dashboard: '1' } },
    data: { [d + '.json']: std.manifestJsonMinified(patchDashboard(dashboards[d])) },
  }
  for d in std.objectFields(dashboards)
  if !std.member(skipDashboards, d)
}
