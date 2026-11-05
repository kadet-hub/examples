import app

web: app.App {
    image = "ghcr.io/example/web:1.5.0-rc.1"
    replicas = 1
    resources = {
        requests = {cpu = "50m", memory = "64Mi"}
        limits.memory = "128Mi"
    }
    config.data.log_level = "debug"
}
api: app.App {
    image = "ghcr.io/example/api:2.0.0-rc.3"
    replicas = 1
    resources = {
        requests = {cpu = "50m", memory = "64Mi"}
        limits.memory = "128Mi"
    }
    config.data.log_level = "debug"
}
