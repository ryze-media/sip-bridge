# Ryze sipgate-to-LiveKit SIP bridge

An Asterisk bridge that registers with a sipgate trunk and forwards inbound
calls to LiveKit SIP. This is a Ryze-specific fork of
[`sipgate/sip-bridge`](https://github.com/sipgate/sip-bridge).

```text
PSTN caller <-> sipgate <-> Asterisk <-> LiveKit SIP <-> LiveKit room/agent
```

The bridge keeps both SIP/RTP legs active, forces media through Asterisk, and
uses PCMA (G.711 A-law) on both sides to avoid transcoding during the initial
deployment.

## Configuration

Copy `.env.example` to `.env` for manual deployment. Never commit `.env`.

| Variable | Purpose |
|---|---|
| `EXTERNAL_IP` | Public IPv4 address of the bridge VPS |
| `SIPGATE_USER` | sipgate trunk SIP ID |
| `SIPGATE_PASS` | sipgate trunk SIP password |
| `SIPGATE_REGISTRAR` | New-platform registrar shown in sipgate; defaults to `sip.sipgate.com` and uses TLS with NAPTR/SRV discovery |
| `LIVEKIT_SIP_HOST` | LiveKit global or region-pinned SIP endpoint, without `sip:` |
| `LIVEKIT_SIP_PORT` | LiveKit SIP port; defaults to `5060` |
| `LIVEKIT_SIP_TRANSPORT` | LiveKit SIP transport; defaults to `tcp` |
| `LIVEKIT_SIP_USER` | Username configured on the LiveKit inbound trunk |
| `LIVEKIT_SIP_PASS` | Password configured on the LiveKit inbound trunk |
| `DEFAULT_COUNTRY_CODE` | Country code used for national number normalization; defaults to `49` |

The LiveKit inbound trunk must contain the sipgate number and matching digest
credentials. Attach an individual dispatch rule that dispatches the
`spark-agent` agent.

The sipgate leg uses the new platform's `sip.sipgate.com` registrar over
TLS/5061. Asterisk sends a `sip:` registration URI with `transport=tls`; the
registrar rejects the stricter `sips:` URI scheme. Do not configure an explicit
load-balancer proxy: DNS NAPTR/SRV discovery provides the targets while keeping
`sip.sipgate.com` as the verified TLS certificate identity.

## Manual deployment

The VPS must expose SIP signalling and the configured RTP range. Restrict SIP
ingress to sipgate's documented networks at the host firewall.

```bash
cp .env.example .env
# Fill in .env.
docker compose config --quiet
docker compose up --detach --build
docker compose ps
```

Useful checks:

```bash
docker exec sip-bridge asterisk -rx "pjsip show registrations"
docker exec sip-bridge asterisk -rx "pjsip show endpoints"
docker exec sip-bridge asterisk -rx "core show channels"
docker compose logs --tail=100
```

## GitHub Actions deployment

`.github/workflows/deploy.yml` deploys every push to `main` on a dedicated
self-hosted runner installed on the VPS. Give the runner these labels:

```text
self-hosted, linux, x64, sip-bridge
```

The runner account needs Docker and Docker Compose access. Create a GitHub
environment named `production` with these secrets:

```text
EXTERNAL_IP
SIPGATE_USER
SIPGATE_PASS
LIVEKIT_SIP_HOST
LIVEKIT_SIP_USER
LIVEKIT_SIP_PASS
```

Optional `production` environment variables:

```text
LIVEKIT_SIP_PORT=5060
LIVEKIT_SIP_TRANSPORT=tcp
SIPGATE_REGISTRAR=sip.sipgate.com
DEFAULT_COUNTRY_CODE=49
```

The deployment builds on the VPS, replaces the Compose service, and waits for
the container to report healthy. A healthy bridge means Asterisk booted and
the sipgate registration is `Registered`.

## Validation

```bash
bash tests/test-config.sh
docker build --tag ryze-sip-bridge:test .
```

CI runs both checks for pull requests and pushes to `main`.

## Number handling

The dialplan normalizes caller and destination numbers to E.164 before
forwarding them to LiveKit:

- `+49...` stays unchanged.
- `0049...` becomes `+49...`.
- `0...` becomes `+<DEFAULT_COUNTRY_CODE>...`.
- A number without an international prefix gets `+` prepended.

Verify the actual sipgate `From` and request URI values with a test call before
production use. Anonymous caller IDs remain empty.
