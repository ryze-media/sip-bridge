#!/usr/bin/env bash
set -euo pipefail

echo "Starting sipgate to LiveKit SIP bridge"
/usr/local/bin/render-config.sh

chown -R asterisk:asterisk /etc/asterisk/
exec asterisk -f -vvv
