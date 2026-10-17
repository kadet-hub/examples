(import 'shop/shop.libsonnet') + {
  _config+:: {
    log_level: 'info',
    apps+: {
      web+: {
        tag:: '1.4.2',
        replicas: 3,
        requests: { cpu: '250m', memory: '256Mi' },
        limits: { memory: '512Mi' },
        pdb_min_available: 2,
      },
      api+: {
        tag:: '1.9.1',
        replicas: 2,
        requests: { cpu: '500m', memory: '512Mi' },
        limits: { memory: '1Gi' },
        pdb_min_available: 1,
      },
    },
  },
}
