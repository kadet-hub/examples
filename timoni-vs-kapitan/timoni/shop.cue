bundle: {
	apiVersion: "v1alpha1"
	name:       "shop"
	instances: [string]: {
		// The registry that check starts; check adds the digest of its push.
		module: {url: "oci://localhost:5001/modules/app", version: "1.0.0"}
		namespace: "shop"
	}
	instances: {
		web: values: {
			port: {container: 8080, service: 80}
			readinessPath: "/ready"
			config: mount: "/etc/web"
		}
		api: values: {
			port: {container: 9090, service: 80}
			readinessPath: "/healthz"
			config: {
				mount: "/etc/api"
				data: web_url: "http://web.\(instances.web.namespace).svc:\(instances.web.values.port.service)"
			}
		}
	}
}
