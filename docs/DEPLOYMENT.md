# Deploying the portfolio demo

The Docker image serves the React build and Rails API from one origin. Use a separate PostgreSQL database and restricted login; never point this demo at a client's logical database. The Fly target is `a3-clausedesk` in Chicago, configured in `fly.toml`.

Required runtime environment:

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | Dedicated PostgreSQL connection with TLS in hosted environments |
| `SECRET_KEY_BASE` | Random server secret, generated and stored in the host's secret manager |
| `APP_HOST` | Exact public hostname without scheme |
| `PUBLIC_DEMO=true` | Enables isolated, synthetic-only sessions |
| `OPENAI_API_KEY`, `OPENAI_MODEL` | Optional live AI for separately provisioned non-demo users |

Build `docker build -t clausedesk .`. The default command runs `db:prepare`, removes expired demo data, and starts Rails on port 3000. Terminate HTTPS at the host's trusted reverse proxy; Rails assumes SSL in production. Use `/up` for health checks. Allow at least 75 seconds for the synchronous AI endpoint or leave AI disabled until a durable worker is added. Configure request-body limits near the app's 2 MB intake limit and use a database connection pool appropriate to the host's replica count.

## Fly operation and cost control

Deploy with `fly deploy --local-only --ha=false` to keep one 512 MB shared-CPU Machine and avoid a paid remote builder. This app uses shared IPv4, no dedicated IPv4, no web-app volume, and no always-on worker. PostgreSQL uses a separate database and non-superuser login on existing agency infrastructure over Fly's encrypted private network; do not expose its connection string in the repository. The database remains available to its existing consumers when this web app stops.

Public requests **cannot wake the app** (`auto_start_machines=false`). An idle running Machine can stop automatically (`auto_stop_machines="stop"`, minimum zero). The URL https://a3-clausedesk.fly.dev is deliberately unavailable while stopped. An operator must start it before sharing a live demonstration:

```sh
fly machine list -a a3-clausedesk
fly machine start <machine-id> -a a3-clausedesk
# After the demonstration, stop explicitly rather than relying on idle detection:
fly machine stop <machine-id> -a a3-clausedesk
```

Every deployment may start the Machine; verify the demo then stop it again. Stopped Machines incur root-filesystem storage costs even though CPU/RAM billing stops. Existing database compute, volumes, snapshots and other services are additional. This configuration is not an organization-wide hard spending cap.

To stage optional provider secrets locally, run `python3 bin/configure-fly-ai`. It asks for the selected model ID and reads the key with hidden input, then sends both directly to Fly secrets. It saves no credential file, does not start the app, and makes no provider call. Never paste the key into chat, source, or a shell command saved in history. Apply staged secrets in the next deployment, verify with a separately provisioned operator account, then stop the app again. Public demo sessions cannot invoke the provider even if credentials are installed. Real model evaluation remains a separate verification step.

Run the public browser journey against the started deployment:

```sh
cd frontend
PLAYWRIGHT_BASE_URL=https://a3-clausedesk.fly.dev npx playwright test --grep 'public demo'
```

Public demo limits: 100 new workspaces per 24 hours across all replicas, two-hour access expiry, five sample documents per workspace. No public uploads or provider spending. Schedule `bin/rails demo:cleanup` daily; retain normal-workspace data according to your own policy. Workspace quotas alone do not replace edge rate limits, monitoring or backup configuration.

Before publishing a URL, verify the production image starts, `/` serves the login page, `/api/capabilities` exposes demo availability, two visitors cannot access each other's documents, and a visitor can review → approve → export. Confirm expiry and cleanup, inspect runtime logs, and check that no secrets are present in browser assets. Account provisioning for non-demo users remains an operator task.
