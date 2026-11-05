package templates

import (
	corev1 "k8s.io/api/core/v1"
)

#Service: corev1.#Service & {
	#config:    #Config
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      #config.metadata.name
		namespace: #config.metadata.namespace
		labels: name: #config.metadata.name
	}
	spec: {
		type:            "ClusterIP"
		sessionAffinity: "None"
		selector: #podLabels & {#name: #config.metadata.name}
		ports: [{
			name:        "http"
			port:        #config.port.service
			targetPort:  "http"
			protocol:    "TCP"
			appProtocol: "http"
		}]
	}
}
