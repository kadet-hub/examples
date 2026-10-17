// Renders one app: ConfigMap, Deployment, Service and, if pdb_min_available
// is set, a PodDisruptionBudget. Field-for-field the same as the Kapitan side.
local k = import 'k.libsonnet';
local cm = k.core.v1.configMap, deploy = k.apps.v1.deployment, svc = k.core.v1.service,
      pdb = k.policy.v1.podDisruptionBudget, container = k.core.v1.container,
      port = k.core.v1.containerPort, volume = k.core.v1.volume,
      mount = k.core.v1.volumeMount, servicePort = k.core.v1.servicePort;

function(name, c) {
  local labels = { name: name },
  local podLabels = labels { 'app.kubernetes.io/name': name },

  configMap: cm.new(name, c.data) + cm.metadata.withLabels(labels),

  deployment:
    deploy.new(name, c.replicas, [
      container.new(name, c.image)
      + container.withImagePullPolicy('IfNotPresent')
      + container.withPorts([port.newNamed(c.container_port, 'http') + port.withProtocol('TCP')])
      + container.readinessProbe.httpGet.withPath(c.ready_path)
      + container.readinessProbe.httpGet.withPort('http')
      + container.readinessProbe.httpGet.withScheme('HTTP')
      + container.readinessProbe.withFailureThreshold(3)
      + container.readinessProbe.withInitialDelaySeconds(0)
      + container.readinessProbe.withPeriodSeconds(10)
      + container.readinessProbe.withSuccessThreshold(1)
      + container.readinessProbe.withTimeoutSeconds(5)
      + container.resources.withRequests(c.requests)
      + container.resources.withLimits(c.limits)
      + container.securityContext.withAllowPrivilegeEscalation(false)
      + container.securityContext.capabilities.withDrop(['ALL'])
      + container.withVolumeMounts([mount.new('config', c.mount)]),
    ], podLabels)
    + deploy.metadata.withLabels(podLabels)
    + deploy.spec.selector.withMatchLabels(labels)
    + deploy.spec.strategy.withType('RollingUpdate')
    + deploy.spec.strategy.rollingUpdate.withMaxSurge('25%')
    + deploy.spec.strategy.rollingUpdate.withMaxUnavailable('25%')
    + deploy.spec.template.spec.withAutomountServiceAccountToken(false)
    + deploy.spec.template.spec.withRestartPolicy('Always')
    + deploy.spec.template.spec.securityContext.withRunAsNonRoot(true)
    + deploy.spec.template.spec.securityContext.seccompProfile.withType('RuntimeDefault')
    + deploy.spec.template.spec.withVolumes([
      volume.fromConfigMap('config', name) + volume.configMap.withDefaultMode(420),
    ]),

  service:
    svc.new(name, podLabels, [servicePort.newNamed('http', c.service_port, 'http') + servicePort.withProtocol('TCP')])
    + svc.metadata.withLabels(labels)
    + svc.spec.withSessionAffinity('None')
    + svc.spec.withType('ClusterIP'),

  [if c.pdb_min_available != null then 'pdb']:
    pdb.new(name)
    + pdb.metadata.withLabels(labels)
    + pdb.spec.withMinAvailable(c.pdb_min_available)
    + pdb.spec.selector.withMatchLabels(podLabels),
}
