import manifests
import app

web: app.App {
    name = "web"
    namespace = "shop"
    port = {container = 8080, service = 80}
    readinessPath = "/ready"
    config.mount = "/etc/web"
}
api: app.App {
    name = "api"
    namespace = "shop"
    port = {container = 9090, service = 80}
    readinessPath = "/healthz"
    config.mount = "/etc/api"
    config.data.web_url = "http://web.${web.namespace}.svc:${web.port.service}"
}
manifests.yaml_stream(app.render(web) + app.render(api))
