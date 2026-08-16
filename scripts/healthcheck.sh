#!/usr/bin/env bash
set -euo pipefail

asterisk -rx "core waitfullybooted" >/dev/null
asterisk -rx "pjsip show registrations" | grep -Eq 'sipgate.*Registered'
