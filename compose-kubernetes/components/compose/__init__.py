"""Docker Compose services from the components of the kubernetes generator.

kadet-hub's docker generator renders Dockerfiles, not Compose files. This
component maps the component keys the miniflux recipe uses and fails on any
other key, so that nothing the cluster gets is dropped without notice.
"""

from kapitan.inputs.kadet import BaseObj, inventory

# Keys without a Compose counterpart. Services reach each other by service
# name on the container port, and a named volume has no size.
DROPPED = {"application", "type", "ports", "service", "volume_claims"}
MAPPED = {"image", "env", "secrets", "healthcheck", "volume_mounts"}
PROBE = {"type", "command", "period_seconds", "timeout_seconds", "failure_threshold"}


def fail(name, what):
    raise ValueError(f"components.{name}: no Compose mapping for {what}")


def service(name, c):
    if set(c) - DROPPED - MAPPED:
        fail(name, sorted(set(c) - DROPPED - MAPPED))
    secret = {}
    for s in c.get("secrets", {}).values():
        if set(s) != {"string_data"}:
            fail(name, f"secrets other than string_data: {sorted(s)}")
        secret.update({k: v["value"] for k, v in s["string_data"].items()})
    env = {}
    for k, v in c.get("env", {}).items():
        if isinstance(v, dict):
            # Compose has no reference from a variable to a secret, so the
            # value goes into the environment.
            if list(v) != ["secretKeyRef"] or list(v["secretKeyRef"]) != ["key"]:
                fail(name, f"env.{k}")
            v = secret[v["secretKeyRef"]["key"]]
        env[k] = str(v)
    out = {"image": c["image"], "environment": env}
    probes = c.get("healthcheck", {})
    if probes:
        p = probes.get("readiness", {})
        # A Docker health check runs inside the container: no http, tcp or
        # grpc probe from outside, and one check instead of three.
        if list(probes) != ["readiness"] or p.get("type") != "command" or set(p) - PROBE:
            fail(name, f"healthcheck {dict(probes)}")
        out["healthcheck"] = {
            "test": ["CMD", *p["command"]],
            # The kubelet's defaults.
            "interval": f"{p.get('period_seconds', 10)}s",
            "timeout": f"{p.get('timeout_seconds', 1)}s",
            "retries": p.get("failure_threshold", 3),
        }
    mounts = c.get("volume_mounts", {})
    for v, m in mounts.items():
        if v not in c.get("volume_claims", {}) or list(m) != ["mount_path"]:
            fail(name, f"volume_mounts.{v}")
    if mounts:
        out["volumes"] = [f"{v}:{m['mount_path']}" for v, m in mounts.items()]
    return out


def merge(base, over):
    for k, v in over.items():
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            merge(base[k], v)
        else:
            base[k] = v


def main(input_params):
    p = inventory().parameters
    services = {name: service(name, c) for name, c in p.components.items()}
    volumes = {v: {} for c in p.components.values() for v in c.get("volume_mounts", {})}
    merge(services, p.get("compose", {}).get("services", {}))
    obj = BaseObj()
    obj.root.compose = {"services": services, "volumes": volumes}
    return obj
