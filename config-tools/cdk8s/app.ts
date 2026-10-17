// Renders one app: ConfigMap, Deployment, Service and, if pdbMinAvailable is
// set, a PodDisruptionBudget. Field-for-field the same as the Kapitan side.
import { Construct } from 'constructs';
import {
  IntOrString, KubeConfigMap, KubeDeployment, KubePodDisruptionBudget, KubeService, Quantity,
} from './imports/k8s';

export interface AppProps {
  readonly image: string;
  readonly containerPort: number;
  readonly servicePort: number;
  readonly readyPath: string;
  readonly mount: string;
  readonly replicas: number;
  readonly requests: { cpu: string; memory: string };
  readonly limits: { memory: string };
  readonly pdbMinAvailable?: number;
  readonly data: Record<string, string>;
}

const q = (o: Record<string, string>) =>
  Object.fromEntries(Object.entries(o).map(([k, v]) => [k, Quantity.fromString(v)]));

export class App extends Construct {
  constructor(scope: Construct, name: string, p: AppProps) {
    super(scope, name);
    const labels = { name };
    const podLabels = { ...labels, 'app.kubernetes.io/name': name };

    new KubeConfigMap(this, 'cm', { metadata: { name, labels }, data: p.data });

    new KubeDeployment(this, 'deploy', {
      metadata: { name, labels: podLabels },
      spec: {
        replicas: p.replicas,
        selector: { matchLabels: labels },
        strategy: {
          type: 'RollingUpdate',
          rollingUpdate: { maxSurge: IntOrString.fromString('25%'), maxUnavailable: IntOrString.fromString('25%') },
        },
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
                httpGet: { path: p.readyPath, port: IntOrString.fromString('http'), scheme: 'HTTP' },
                failureThreshold: 3,
                initialDelaySeconds: 0,
                periodSeconds: 10,
                successThreshold: 1,
                timeoutSeconds: 5,
              },
              resources: { requests: q(p.requests), limits: q(p.limits) },
              securityContext: { allowPrivilegeEscalation: false, capabilities: { drop: ['ALL'] } },
              volumeMounts: [{ name: 'config', mountPath: p.mount }],
            }],
            volumes: [{ name: 'config', configMap: { name, defaultMode: 420 } }],
          },
        },
      },
    });

    new KubeService(this, 'svc', {
      metadata: { name, labels },
      spec: {
        type: 'ClusterIP',
        sessionAffinity: 'None',
        selector: podLabels,
        ports: [{ name: 'http', port: p.servicePort, targetPort: IntOrString.fromString('http'), protocol: 'TCP' }],
      },
    });

    if (p.pdbMinAvailable !== undefined) {
      new KubePodDisruptionBudget(this, 'pdb', {
        metadata: { name, labels },
        spec: { minAvailable: IntOrString.fromNumber(p.pdbMinAvailable), selector: { matchLabels: podLabels } },
      });
    }
  }
}
