import { App as CdkApp, Chart } from 'cdk8s';
import { App } from './app';

interface Sizing { tag: string; replicas: number; requests: { cpu: string; memory: string }; limits: { memory: string }; pdbMinAvailable?: number }
interface Env { logLevel: string; web: Sizing; api: Sizing }

const envs: Record<string, Env> = {
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

const app = new CdkApp();
for (const [envName, e] of Object.entries(envs)) {
  const chart = new Chart(app, envName, { namespace: 'shop', disableResourceNameHashes: true });
  const { tag, ...web } = e.web;
  const webProps = {
    ...web,
    image: `ghcr.io/example/web:${tag}`,
    containerPort: 8080,
    servicePort: 80,
    readyPath: '/ready',
    mount: '/etc/web',
    data: { log_level: e.logLevel },
  };
  new App(chart, 'web', webProps);
  const { tag: apiTag, ...api } = e.api;
  new App(chart, 'api', {
    ...api,
    image: `ghcr.io/example/api:${apiTag}`,
    containerPort: 9090,
    servicePort: 80,
    readyPath: '/healthz',
    mount: '/etc/api',
    data: { log_level: e.logLevel, web_url: `http://web.${chart.namespace}.svc:${webProps.servicePort}` },
  });
}
app.synth();
