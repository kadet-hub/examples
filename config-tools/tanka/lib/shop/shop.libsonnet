local app = import 'app.libsonnet';

{
  _config:: {
    namespace: 'shop',
    log_level: error 'log_level must be set per environment',
    apps: {
      web: {
        tag:: error 'web tag must be set per environment',
        image: 'ghcr.io/example/web:' + self.tag,
        container_port: 8080,
        service_port: 80,
        ready_path: '/ready',
        mount: '/etc/web',
        replicas: 1,
        requests: {},
        limits: {},
        pdb_min_available: null,
        data: { log_level: $._config.log_level },
      },
      api: {
        tag:: error 'api tag must be set per environment',
        image: 'ghcr.io/example/api:' + self.tag,
        container_port: 9090,
        service_port: 80,
        ready_path: '/healthz',
        mount: '/etc/api',
        replicas: 1,
        requests: {},
        limits: {},
        pdb_min_available: null,
        data: {
          log_level: $._config.log_level,
          web_url: 'http://web.%s.svc:%d' % [$._config.namespace, $._config.apps.web.service_port],
        },
      },
    },
  },

  apps: { [name]: app(name, $._config.apps[name]) for name in std.objectFields($._config.apps) },
}
