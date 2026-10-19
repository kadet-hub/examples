// Renders web and api for the environment named by the stack (dev or prod)
// into rendered/<stack>, without a cluster.
import * as pulumi from '@pulumi/pulumi';
import * as k8s from '@pulumi/kubernetes';

interface Sizing { tag: string; replicas: number; requests: { cpu: string; memory: string }; limits: { memory: string }; pdbMinAvailable?: number }
interface App extends Sizing { image: string; containerPort: number; servicePort: number; readyPath: string; mount: string; data: Record<string, string> }

const envs: Record<string, { logLevel: string; web: Sizing; api: Sizing }> = {
  dev: {
    logLevel: 'debug',
    web: { tag: '1.5.0-rc.1', replicas: 1, requests: { cpu: '50m', memory: '64Mi' }, limits: { memory: '128Mi' } },
    api: { tag: '2.0.0-rc.3', replicas: 1, requests: { cpu: '50m', memory: '64Mi' }, limits: { memory: '128Mi' } },
  },
  prod: {
    logLevel: 'info',
    web: { tag: '1.4.2', replicas: 3, requests: { cpu: '250m', memory: '256Mi' }, limits: { memory: '512Mi' }, pdbMinAvailable: 2 },
    api: { tag: '1.9.1', replicas: 2, requests: { cpu: '500m', memory: '512Mi' }, limits: { memory: '1Gi' }, pdbMinAvailable: 1 },
  },
};

const namespace = 'shop';
const e = envs[pulumi.getStack()];
const provider = new k8s.Provider('render', { renderYamlToDirectory: `rendered/${pulumi.getStack()}` });
const opts = { provider };

function app(name: string, p: App) {
  const labels = { name };
  const podLabels = { ...labels, 'app.kubernetes.io/name': name };

  new k8s.core.v1.ConfigMap(`${name}-cm`, { metadata: { name, namespace, labels }, data: p.data }, opts);

  new k8s.apps.v1.Deployment(`${name}-deploy`, {
    metadata: { name, namespace, labels: podLabels },
    spec: {
      replicas: p.replicas,
      selector: { matchLabels: labels },
      strategy: { type: 'RollingUpdate', rollingUpdate: { maxSurge: '25%', maxUnavailable: '25%' } },
      template: {
        metadata: { labels: podLabels },
        spec: {
          automountServiceAccountToken: false,
          restartPolicy: 'Always',
          securityContext: { runAsNonRoot: true, seccompProfile: { type: 'RuntimeDefault' } },
          containers: [{
            name,
            image: p.image,
            imagePullPolicy: 'IfNotPresent',
            ports: [{ name: 'http', containerPort: p.containerPort, protocol: 'TCP' }],
            readinessProbe: {
              httpGet: { path: p.readyPath, port: 'http', scheme: 'HTTP' },
              failureThreshold: 3,
              initialDelaySeconds: 0,
              periodSeconds: 10,
              successThreshold: 1,
              timeoutSeconds: 5,
            },
            resources: { requests: p.requests, limits: p.limits },
            securityContext: { allowPrivilegeEscalation: false, capabilities: { drop: ['ALL'] } },
            volumeMounts: [{ name: 'config', mountPath: p.mount }],
          }],
          volumes: [{ name: 'config', configMap: { name, defaultMode: 420 } }],
        },
      },
    },
  }, opts);

  new k8s.core.v1.Service(`${name}-svc`, {
    metadata: { name, namespace, labels },
    spec: {
      type: 'ClusterIP',
      sessionAffinity: 'None',
      selector: podLabels,
      ports: [{ name: 'http', port: p.servicePort, targetPort: 'http', protocol: 'TCP' }],
    },
  }, opts);

  if (p.pdbMinAvailable !== undefined) {
    new k8s.policy.v1.PodDisruptionBudget(`${name}-pdb`, {
      metadata: { name, namespace, labels },
      spec: { minAvailable: p.pdbMinAvailable, selector: { matchLabels: podLabels } },
    }, opts);
  }
}

const web = { ...e.web, image: `ghcr.io/example/web:${e.web.tag}`, containerPort: 8080, servicePort: 80, readyPath: '/ready', mount: '/etc/web', data: { log_level: e.logLevel } };
app('web', web);
app('api', {
  ...e.api,
  image: `ghcr.io/example/api:${e.api.tag}`,
  containerPort: 9090,
  servicePort: 80,
  readyPath: '/healthz',
  mount: '/etc/api',
  data: { log_level: e.logLevel, web_url: `http://web.${namespace}.svc:${web.servicePort}` },
});
