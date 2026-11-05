import app

web: app.App {
    image = "ghcr.io/example/web:1.4.2"
    replicas = 3
    resources = {
        requests = {cpu = "250m", memory = "256Mi"}
        limits.memory = "512Mi"
    }
    config.data.log_level = "info"
    pdbMinAvailable = 2
}
api: app.App {
    image = "ghcr.io/example/api:1.9.1"
    replicas = 2
    resources = {
        requests = {cpu = "500m", memory = "512Mi"}
        limits.memory = "1Gi"
    }
    config.data.log_level = "info"
    pdbMinAvailable = 1
}
