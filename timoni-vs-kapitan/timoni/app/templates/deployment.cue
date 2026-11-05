package templates

import (
	appsv1 "k8s.io/api/apps/v1"
)

#Deployment: appsv1.#Deployment & {
	#config:    #Config
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		name:      #config.metadata.name
		namespace: #config.metadata.namespace
		labels: #podLabels & {#name: #config.metadata.name}
	}
	spec: {
		replicas: #config.replicas
		selector: matchLabels: name: #config.metadata.name
		strategy: {
			type: "RollingUpdate"
			rollingUpdate: {maxSurge: "25%", maxUnavailable: "25%"}
		}
		template: {
			metadata: labels: #podLabels & {#name: #config.metadata.name}
			spec: {
				automountServiceAccountToken: false
				restartPolicy:                "Always"
				securityContext: {
					runAsNonRoot: true
					seccompProfile: type: "RuntimeDefault"
				}
				containers: [{
					name:            #config.metadata.name
					image:           #config.image
					imagePullPolicy: "IfNotPresent"
					ports: [{name: "http", containerPort: #config.port.container, protocol: "TCP"}]
					readinessProbe: {
						httpGet: {path: #config.readinessPath, port: "http", scheme: "HTTP"}
						initialDelaySeconds: 0
						periodSeconds:       10
						timeoutSeconds:      5
						successThreshold:    1
						failureThreshold:    3
					}
					resources: #config.resources
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
					}
					volumeMounts: [{name: "config", mountPath: #config.config.mount}]
				}]
				volumes: [{
					name: "config"
					configMap: {name: #config.metadata.name, defaultMode: 420}
				}]
			}
		}
	}
}
