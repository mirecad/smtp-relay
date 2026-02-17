# SMTP Relay Test Server

Minimal SMTP server that accepts all incoming mail and logs metadata (from, to, subject, timestamp) to the console. No actual mail delivery — for relay behavior testing only.

No TLS, no authentication.

## Run locally

```bash
go run .
```

Override defaults with environment variables:

```bash
SMTP_PORT=2525 SMTP_DOMAIN=example.com go run .
```

## Deploy to Azure

Requires Docker and `az` CLI (logged in).

```bash
./deploy.sh
```

Re-run the same script to redeploy after code changes.

## Test

```bash
# telnet
telnet <FQDN> 587

# swaks
swaks --to test@example.com --from sender@example.com --server <FQDN> --port 587
```

## View logs

```bash
az container logs -g smtp-relay-rg -n smtp-relay --follow
```

## Tear down

```bash
az group delete --name smtp-relay-rg --yes
```
