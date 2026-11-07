# EX-32: the logins of alice and bob in a headless Chromium, run by check
# once tests/chainsaw-test.yaml found everything ready. Arguments: the CA
# certificate and the class sso as `kapitan inventory -F` prints it. The
# passwords come in PASSWORD_ALICE and PASSWORD_BOB.
#
# Chromium reaches each URL of the class sso through a port-forward on a
# free local port. --host-resolver-rules maps the URL's name and port to it
# and leaves the URL unchanged, so Keycloak and the apps see the same URLs as
# from a browser on the network. Chromium on Linux trusts the CAs of the NSS
# database in $HOME/.pki/nssdb, where the CA goes. One browser context is
# one user's cookie jar.
#
# An app is one entry in apps: its login path, the Service behind its URL
# and the function that names the user of its session.
import os
import re
import subprocess
import sys
import tempfile
import threading
from datetime import datetime, timezone
from typing import Callable, NamedTuple
from urllib.parse import parse_qs, quote, urlsplit

from playwright.sync_api import sync_playwright

ca, inventory = sys.argv[1:]
with open(inventory) as f:
    sso = dict(line.split(": ", 1) for line in f.read().splitlines())
issuer = sso["issuer"]


def gitea_user(page, url):
    """Gitea 28's API takes tokens only, so its settings page names the user."""
    page.goto(f"{url}/user/settings")
    field = page.locator("input#username")
    return field.get_attribute("value") if field.count() else ""


def open_webui_user(page, url):
    return page.goto(f"{url}/api/v1/auths/").json().get("email", "")


def miniflux_user(page, url):
    page.goto(f"{url}/unread")
    m = re.search(r'title="Logged in as ([^"]*)"', page.content())
    return m[1] if m else ""


def mattermost_user(page, url):
    return page.goto(f"{url}/api/v4/users/me").json().get("username", "")


def matrix_synapse_user(page, url):
    """Synapse keeps no browser session. A client signs in through SSO: the
    page Synapse ends on links to the client with a login token, which the
    client trades once for an access token, which /whoami names."""
    page.goto(url + apps["matrix-synapse"].login)
    link = page.locator('a[href*="loginToken="]')
    if not link.count():
        return ""
    token = parse_qs(urlsplit(link.first.get_attribute("href")).query)["loginToken"][0]
    return page.evaluate("""async token => {
        const login = await fetch("/_matrix/client/v3/login",
            {method: "POST", body: JSON.stringify({type: "m.login.token", token})});
        const {access_token} = await login.json();
        if (!access_token) return "";
        const whoami = await fetch("/_matrix/client/v3/account/whoami",
            {headers: {Authorization: `Bearer ${access_token}`}});
        return (await whoami.json()).user_id || "";
    }""", token)


class App(NamedTuple):
    url: str
    login: str  # path that starts the authorization code flow
    service: tuple  # namespace, Service and port behind url
    user: Callable  # (page, url) -> the session's user, empty without one


apps = {
    "gitea": App(sso["clients.gitea.url"], "/user/oauth2/keycloak", ("gitea", "gitea-http", 3000), gitea_user),
    "open-webui": App(sso["clients.open-webui.url"], "/oauth/oidc/login", ("open-webui", "open-webui", 80),
                      open_webui_user),
    "miniflux": App(sso["clients.miniflux.url"], "/oauth2/oidc/redirect", ("miniflux", "miniflux", 80),
                    miniflux_user),
    "mattermost": App(sso["clients.mattermost.url"], "/oauth/gitlab/login",
                      ("mattermost", "mattermost-team-edition", 8065), mattermost_user),
    # Synapse appends the login token to the client's URL, any URL here.
    "matrix-synapse": App(sso["clients.matrix-synapse.url"],
                          "/_matrix/client/v3/login/sso/redirect/oidc?redirectUrl="
                          + quote(sso["clients.matrix-synapse.url"] + "/", safe=""),
                          ("matrix-synapse", "matrix-synapse", 8443), matrix_synapse_user),
}
service = {issuer: ("keycloak", "keycloak-service", 8443)} | {app.url: app.service for app in apps.values()}
forwards = []


def kubectl(*args):
    return subprocess.run(["kubectl", *args], check=True, stdout=subprocess.PIPE, text=True).stdout


def forward(url):
    """Starts a port-forward to the Service behind url, returns the local port."""
    namespace, name, port = service[url]
    p = subprocess.Popen(["kubectl", "-n", namespace, "port-forward", f"service/{name}", f":{port}"],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    forwards.append(p)
    line = p.stdout.readline()
    m = re.match(r"Forwarding from 127\.0\.0\.1:(\d+) ", line)
    if not m:
        sys.exit(f"port-forward to {namespace}/{name}: {line}")
    threading.Thread(target=p.stdout.read, daemon=True).start()  # drains "Handling connection"
    return m[1]


def launch(playwright, home, ports):
    """Chromium that sends each URL of ports to its local port and resolves no other name."""
    def name_port(url):
        u = urlsplit(url)
        return f"{u.hostname}:{u.port or {'http': 80, 'https': 443}[u.scheme]}"
    rules = ", ".join([f"MAP {name_port(u)} 127.0.0.1:{p}" for u, p in ports.items()] + ["MAP * ~NOTFOUND"])
    return playwright.chromium.launch(args=[f"--host-resolver-rules={rules}"], env={**os.environ, "HOME": home})


def login(context, app, user=None, password=None):
    """The authorization code flow as a browser runs it. The app's login URL
    redirects to Keycloak, which shows its login form unless the context holds
    a Keycloak session. The form's POST redirects to the app's redirect URI
    with a code, which the app exchanges for tokens over its own connection to
    Keycloak. Returns the page where the browser ended."""
    page = context.new_page()
    page.goto(apps[app].url + apps[app].login)
    if not page.locator("#kc-form-login").count():  # Keycloak's session signed the browser in
        return page
    if user is None:
        sys.exit(f"Keycloak asked for a password at {apps[app].url + apps[app].login}")
    page.fill("#username", user)
    page.fill("#password", password)
    with page.expect_navigation():
        page.click("#kc-login")
    return page


def session_user(context, app):
    page = context.new_page()
    try:
        return apps[app].user(page, apps[app].url)
    finally:
        page.close()


with tempfile.TemporaryDirectory() as home, sync_playwright() as playwright:
    try:
        nssdb = f"sql:{home}/.pki/nssdb"
        os.makedirs(f"{home}/.pki/nssdb")
        subprocess.run(["certutil", "-d", nssdb, "-N", "--empty-password"], check=True)
        subprocess.run(["certutil", "-d", nssdb, "-A", "-t", "C,,", "-n", "sso", "-i", ca], check=True)
        ports = {url: forward(url) for url in service}
        browser = launch(playwright, home, ports)
        page = browser.new_page()
        print("issuer", page.goto(f"{issuer}/.well-known/openid-configuration").json()["issuer"])
        page.close()

        # alice, in the groups git and chat, types her password once, at
        # Gitea's login. The other apps get her from Keycloak's session.
        alice = browser.new_context()
        for app in apps:
            if app == "gitea":
                end = login(alice, app, "alice", os.environ["PASSWORD_ALICE"]).url
                how = "with her password"
            else:
                end = login(alice, app).url
                how = "through Keycloak's session"
            user = session_user(alice, app)
            if user not in ("alice", "alice@example.test", "@alice:example.test"):
                sys.exit(f"{app}: alice ended at {end} as '{user}'")
            print(f"{app}: alice signed in as {user} {how}, ended at {end.split('?')[0]}")
        role = alice.new_page().goto(f"{apps['open-webui'].url}/api/v1/auths/").json()["role"]
        print(f"open-webui: alice has the role {role}")
        # The recipe's Job created the first account, the system admin.
        me = alice.new_page().goto(f"{apps['mattermost'].url}/api/v4/users/me").json()
        if (me["auth_service"], me["auth_data"]) != ("gitlab", "1") or "system_admin" in me["roles"].split():
            sys.exit(f"mattermost: alice has {me}")
        print(f"mattermost: alice has the auth service {me['auth_service']}, the auth data {me['auth_data']}"
              f" and the roles {me['roles']}")

        # A wrong password: Keycloak shows its form again and no app gets a session.
        for app in apps:
            wrong = browser.new_context()
            page = login(wrong, app, "alice", os.urandom(12).hex())
            if "Invalid username or password." not in page.content() or not page.url.startswith(f"{issuer}/"):
                sys.exit(f"{app}: a wrong password ended at {page.url}")
            if session_user(wrong, app):
                sys.exit(f"{app}: a session after a wrong password")
        print("a wrong password: Keycloak answered 'Invalid username or password.' and no app has a session")

        # bob is in the group family only. Gitea requires git in the claim
        # groups, Open WebUI and Synapse chat. Miniflux and Mattermost check
        # no group.
        bob = browser.new_context()
        page = login(bob, "gitea", "bob", os.environ["PASSWORD_BOB"])
        if not page.title().startswith("Sign-In Prohibited") or session_user(bob, "gitea"):
            sys.exit(f"gitea: bob ended at {page.url} as '{session_user(bob, 'gitea')}'")
        print("gitea: bob, not in git, got 'Sign-In Prohibited' and no session")
        end = login(bob, "open-webui").url
        if not end.startswith(f"{apps['open-webui'].url}/auth?error=") or session_user(bob, "open-webui"):
            sys.exit(f"open-webui: bob ended at {end} as '{session_user(bob, 'open-webui')}'")
        error = end.split("error=", 1)[1].replace("+", " ")
        print(f"open-webui: bob, not in chat, was sent to /auth with '{error}' and no session")
        end = login(bob, "miniflux").url
        if session_user(bob, "miniflux") != "bob":
            sys.exit(f"miniflux: bob ended at {end}")
        print("miniflux: bob signed in as bob")
        end = login(bob, "mattermost").url
        if session_user(bob, "mattermost") != "bob":
            sys.exit(f"mattermost: bob ended at {end}")
        print("mattermost: bob signed in as bob")
        page = login(bob, "matrix-synapse")
        if "You are not allowed to log in here." not in page.content() or session_user(bob, "matrix-synapse"):
            sys.exit(f"matrix-synapse: bob ended at {page.url} as '{session_user(bob, 'matrix-synapse')}'")
        print("matrix-synapse: bob, not in chat, got 'You are not allowed to log in here.' and no login token")
        browser.close()

        # The classic pitfall: an app that reads Keycloak's in-cluster name.
        # Keycloak answers with the issuer of its hostname, which go-oidc in
        # Miniflux refuses. Miniflux reads the discovery document on each
        # login, and the port-forward needs the new pod.
        internal = f"https://keycloak-service.keycloak.svc:8443{urlsplit(issuer).path}"
        kubectl("-n", "miniflux", "set", "env", "deployment/miniflux", f"OAUTH2_OIDC_DISCOVERY_ENDPOINT={internal}")
        kubectl("-n", "miniflux", "rollout", "status", "deployment/miniflux", "--timeout=300s")
        pod = kubectl("-n", "miniflux", "get", "pods", "-l", "name=miniflux",
                      "--sort-by=.metadata.creationTimestamp", "-o", "name").split()[-1]
        rss = apps["miniflux"].url
        ports[rss] = forward(rss)
        since = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        page = launch(playwright, home, ports).new_page()
        page.goto(rss + apps["miniflux"].login)
        end = page.url
        if end.startswith(f"{issuer}/"):
            sys.exit(f"miniflux with the issuer {internal} sent the browser to {end}")
        logs = kubectl("-n", "miniflux", "logs", pod, f"--since-time={since}")
        error = "\n".join(line for line in logs.splitlines() if "Failed to initialize OIDC provider" in line)
        if not error:
            sys.exit(f"miniflux logged no OIDC error with the issuer {internal}")
        if f'did not match the issuer URL returned by provider (\\"{issuer}\\")' not in error:
            sys.exit(f"miniflux: {error}")
        print(f"miniflux with the issuer {internal}: the login ended at {end}, and Miniflux logged")
        print(error)
    finally:
        for p in forwards:
            p.terminate()
