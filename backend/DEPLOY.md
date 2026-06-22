# Deploying june-backend to Fly.io

Runbook. Run from `/Users/sratanjee/June/backend`.

## One-time setup

1. Install + auth:
   ```bash
   brew install flyctl
   fly auth login
   ```

2. Create the app (skip the generated config — we already have `fly.toml`):
   ```bash
   fly launch --no-deploy --copy-config --name june-backend --region iad
   ```
   If prompted to overwrite `fly.toml`, say **no**.

3. Set production secrets (values come from `backend/.env`):
   ```bash
   fly secrets set \
     ANTHROPIC_API_KEY=sk-ant-... \
     SUPABASE_URL=https://<ref>.supabase.co \
     SUPABASE_SERVICE_ROLE_KEY=eyJ... \
     SUPABASE_JWT_SECRET=... \
     PLAID_CLIENT_ID=... \
     PLAID_SECRET=... \
     PLAID_ENV=production \
     DATABASE_URL=postgres://... \
     JOB_KEY=$(openssl rand -hex 24) \
     PLAID_WEBHOOK_URL=https://june-jy5ddq.fly.dev/plaid/webhook
   ```
   List with `fly secrets list`. Update any value the same way; Fly restarts the machine.

   **`JOB_KEY`** is the shared secret supercronic uses in the `x-job-key` header
   when posting to `/jobs/morning-sync-and-checkin`. Generate fresh and treat
   like any other API token.

   **`PLAID_WEBHOOK_URL`** is the public URL Plaid posts webhooks to. The
   `linkTokenCreate` call passes it through so every Item ends up wired to this
   endpoint.

## Every deploy

The personality spec lives one directory up, so copy it into the build context first:

```bash
cp ../June_Personality_Spec.md ./June_Personality_Spec.md
fly deploy
```

`June_Personality_Spec.md` inside `backend/` is git-ignored — re-copy before each deploy so the bundled spec stays in sync with the source.

## Morning cron job

The Docker image bakes in [supercronic](https://github.com/aptible/supercronic)
plus the `crontab` file in this directory. `start.sh` backgrounds supercronic
and execs the Node server, so a single Fly machine runs both. The schedule:

```
0 12 * * *   POST /jobs/morning-sync-and-checkin    # 12:00 UTC daily
```

To inspect cron behavior:

```bash
fly ssh console -C "ps aux | grep supercronic"
fly logs                                          # supercronic logs to stdout
```

To kick the job manually (server-side):

```bash
fly ssh console -C "curl -sf -X POST -H \"x-job-key: $JOB_KEY\" http://localhost:8080/jobs/morning-sync-and-checkin"
```

## Inspect

```bash
fly logs                  # stream live logs
fly status                # machine count + health
fly ssh console           # exec into the running container
fly machine list          # raw machine state
curl https://june-backend.fly.dev/health
```

## Scaling

```bash
fly scale count 1                       # single machine (default)
fly scale memory 1024                   # bump RAM if Anthropic calls OOM
fly scale vm shared-cpu-2x              # bigger VM
```

## Rollback

```bash
fly releases                            # find a known-good version
fly deploy --image <image-ref-from-list>
```
