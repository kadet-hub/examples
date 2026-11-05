package templates

import (
	policyv1 "k8s.io/api/policy/v1"
)

#PodDisruptionBudget: policyv1.#PodDisruptionBudget & {
	#config:    #Config
	apiVersion: "policy/v1"
	kind:       "PodDisruptionBudget"
	metadata: {
		name:      #config.metadata.name
		namespace: #config.metadata.namespace
		labels: name: #config.metadata.name
	}
	spec: {
		minAvailable: #config.pdbMinAvailable
		selector: matchLabels: #podLabels & {#name: #config.metadata.name}
	}
}
