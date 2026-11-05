package templates

import (
	corev1 "k8s.io/api/core/v1"
)

#ConfigMap: corev1.#ConfigMap & {
	#config:    #Config
	apiVersion: "v1"
	kind:       "ConfigMap"
	metadata: {
		name:      #config.metadata.name
		namespace: #config.metadata.namespace
		labels: name: #config.metadata.name
	}
	data: #config.config.data
}
