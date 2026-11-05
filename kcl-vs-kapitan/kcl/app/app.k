import k8s.api.apps.v1 as appsv1
import k8s.api.core.v1 as corev1
import k8s.api.policy.v1 as policyv1

schema Port:
    container: int
    service: int = 80

    check:
        0 < container <= 65535
        0 < service <= 65535

schema Config:
    mount: str
    data: {str:str} = {}

schema App:
    """The values of one app. A schema is closed: an attribute it does not declare is an error."""
    name: str
    namespace: str
    image: str
    replicas: int = 1
    port: Port
    readinessPath: str
    resources: corev1.ResourceRequirements
    config: Config
    # A PodDisruptionBudget is rendered only when this is set.
    pdbMinAvailable?: int

    check:
        replicas > 0
        pdbMinAvailable > 0 if pdbMinAvailable != Undefined

# Labels the pods carry and that the Service and the PDB select.
podLabels = lambda name: str -> {str:str} {
    {"app.kubernetes.io/name" = name, "name" = name}
}

render = lambda a: App -> [any] {
    _meta = {name = a.name, namespace = a.namespace, labels = {"name" = a.name}}
    [
        corev1.ConfigMap {
            metadata = _meta
            data = a.config.data
        }
        corev1.Service {
            metadata = _meta
            spec = {
                type = "ClusterIP"
                sessionAffinity = "None"
                selector = podLabels(a.name)
                ports = [{name = "http", port = a.port.service, targetPort = "http", protocol = "TCP", appProtocol = "http"}]
            }
        }
        appsv1.Deployment {
            metadata = _meta | {labels = podLabels(a.name)}
            spec = {
                replicas = a.replicas
                selector.matchLabels = {"name" = a.name}
                strategy = {type = "RollingUpdate", rollingUpdate = {maxSurge = "25%", maxUnavailable = "25%"}}
                template = {
                    metadata.labels = podLabels(a.name)
                    spec = {
                        automountServiceAccountToken = False
                        restartPolicy = "Always"
                        securityContext = {runAsNonRoot = True, seccompProfile.type = "RuntimeDefault"}
                        containers = [{
                            name = a.name
                            image = a.image
                            imagePullPolicy = "IfNotPresent"
                            ports = [{name = "http", containerPort = a.port.container, protocol = "TCP"}]
                            readinessProbe = {
                                httpGet = {path = a.readinessPath, port = "http", scheme = "HTTP"}
                                initialDelaySeconds = 0
                                periodSeconds = 10
                                timeoutSeconds = 5
                                successThreshold = 1
                                failureThreshold = 3
                            }
                            resources = a.resources
                            securityContext = {allowPrivilegeEscalation = False, capabilities.drop = ["ALL"]}
                            volumeMounts = [{name = "config", mountPath = a.config.mount}]
                        }]
                        volumes = [{name = "config", configMap = {name = a.name, defaultMode = 420}}]
                    }
                }
            }
        }
        if a.pdbMinAvailable != Undefined:
            policyv1.PodDisruptionBudget {
                metadata = _meta
                spec = {minAvailable = a.pdbMinAvailable, selector.matchLabels = podLabels(a.name)}
            }
    ]
}
