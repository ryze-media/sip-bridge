#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$(mktemp -d)"
trap 'rm -rf "$output_dir"' EXIT

export EXTERNAL_IP="203.0.113.10"
export SIPGATE_USER="1234567t0"
export SIPGATE_PASS="sipgate-test-secret"
export SIPGATE_REGISTRAR="sip.sipgate.com"
export LIVEKIT_SIP_HOST="example.sip.livekit.cloud"
export LIVEKIT_SIP_PORT="5060"
export LIVEKIT_SIP_TRANSPORT="tcp"
export LIVEKIT_SIP_USER="livekit-user"
export LIVEKIT_SIP_PASS="livekit-test-secret"
export DEFAULT_COUNTRY_CODE="49"
export CONFIG_OUTPUT_DIR="$output_dir"
export CONFIG_TEMPLATE_DIR="$repo_dir/config"
export RTP_TEMPLATE="$repo_dir/tests/fixtures/rtp.conf.tmpl"

"$repo_dir/scripts/render-config.sh"

pjsip="$output_dir/pjsip.conf"
extensions="$output_dir/extensions.conf"
rtp="$output_dir/rtp.conf"

grep -Fq 'outbound_auth=livekit-auth' "$pjsip"
grep -Fq 'server_uri=sip:sip.sipgate.com' "$pjsip"
grep -Fq 'client_uri=sip:1234567t0@sip.sipgate.com' "$pjsip"
grep -Fq 'from_domain=sip.sipgate.com' "$pjsip"
grep -Fq 'username=livekit-user' "$pjsip"
grep -Fq 'password=livekit-test-secret' "$pjsip"
grep -Fq 'contact=sip:example.sip.livekit.cloud:5060\;transport=tcp' "$pjsip"
grep -Fq 'direct_media=no' "$pjsip"
grep -Fq 'allow=alaw' "$pjsip"
grep -Fq 'Dial(PJSIP/${NORMALIZED_DIALED_NUMBER}@livekit,60)' "$extensions"
grep -Fq 'Set(CALLERID(num)=${NORMALIZED_CALLER_NUMBER})' "$extensions"
grep -Fq 'same => n,GotoIf($["${NUMBER:0:1}" = "+"]?done)' "$extensions"
grep -Fq 'same => n,Set(NUMBER=+${NUMBER})' "$extensions"
grep -Fq 'same => n(national),Set(NUMBER=+49${NUMBER:1})' "$extensions"
grep -Fq 'externaddr=203.0.113.10' "$rtp"

render_log="$($repo_dir/scripts/render-config.sh 2>&1)"
if grep -Fq 'sipgate-test-secret' <<<"$render_log" || grep -Fq 'livekit-test-secret' <<<"$render_log"; then
  echo "render-config.sh leaked a secret" >&2
  exit 1
fi

echo "configuration rendering tests passed"
