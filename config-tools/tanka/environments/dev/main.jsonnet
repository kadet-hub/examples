(import 'shop/shop.libsonnet') + {
  _config+:: {
    log_level: 'debug',
    apps+: {
      web+: {
        tag:: '1.5.0-rc.1',
        replicas: 1,
        requests: { cpu: '50m', memory: '64Mi' },
        limits: { memory: '128Mi' },
      },
      api+: {
        tag:: '2.0.0-rc.3',
        replicas: 1,
        requests: { cpu: '50m', memory: '64Mi' },
        limits: { memory: '128Mi' },
      },
    },
  },
}
