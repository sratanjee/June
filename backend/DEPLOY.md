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
     DATABASE_URL=postgres://...
   ```
   List with `fly secrets list`. Update any value the same way; Fly restarts the machine.

## Every deploy

The personality spec lives one directory up, so copy it into the build context first:

```bash
cp ../June_Personality_Spec.md ./June_Personality_Spec.md
fly deploy
```

`June_Personality_Spec.md` inside `backend/` is git-ignored — re-copy before each deploy so the bundled spec stays in sync with the source.

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
