package main

import (
	templates "timoni.sh/app/templates"
)

// Timoni unifies the bundle's values with this schema and fails on a
// value that does not fit it.
values: templates.#Config

timoni: {
	apiVersion: "v1alpha1"

	instance: templates.#Instance & {
		config: values
		// Set by Timoni from the instance name and namespace in the bundle.
		config: metadata: {
			name:      string @tag(name)
			namespace: string @tag(namespace)
		}
	}

	apply: app: [for obj in instance.objects {obj}]
}
