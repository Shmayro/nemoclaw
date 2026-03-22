#!/bin/bash
TTYD_ARGS=("-p" "7681")
if [ -n "${TTYD_USER}" ] && [ -n "${TTYD_PASS}" ]; then
  TTYD_ARGS+=("-c" "${TTYD_USER}:${TTYD_PASS}")
fi
exec /usr/bin/ttyd "${TTYD_ARGS[@]}" /bin/bash -l
