package templates

import (
	corev1 "k8s.io/api/core/v1"
)

// Config is the schema of the values a bundle passes to an instance.
// A definition is closed: a field it does not declare is an error.
#Config: {
	metadata: {
		name:      string
		namespace: string
	}

	image!:   string
	replicas: *1 | int & >0
	port: {
		container!: int & >0 & <=65535
		service:    *80 | int & >0 & <=65535
	}
	readinessPath!: string
	resources!:     corev1.#ResourceRequirements
	config: {
		mount!: string
		data: [string]: string
	}
	// A PodDisruptionBudget is rendered only when this is set.
	pdbMinAvailable?: int & >0
}

#Instance: {
	config: #Config

	objects: {
		deploy: #Deployment & {#config: config}
		svc: #Service & {#config: config}
		cm: #ConfigMap & {#config: config}
		if config.pdbMinAvailable != _|_ {
			pdb: #PodDisruptionBudget & {#config: config}
		}
	}
}

// Labels the pods carry and that the Service and the PDB select.
#podLabels: {
	#name:                    string
	"app.kubernetes.io/name": #name
	name:                     #name
}
