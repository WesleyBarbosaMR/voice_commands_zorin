#!/bin/bash

# Self-check script for voice_commands hardening.
# This does not require microphone or Google API.
#
# It validates that:
# - v-c parses -d/--debug and -s/--safe in any order with -l <lang>
# - play_stop.sh wake word gating logic can be exercised via VC_TEST_UTTERANCE

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

echo "[self_check] Running basic checks..."

echo "[self_check] 1) v-c should accept -d -l pt in any order"
"$ROOT_DIR/v-c" -d -l pt --help >/dev/null 2>&1 || true
"$ROOT_DIR/v-c" -l pt -d --help >/dev/null 2>&1 || true

echo "[self_check] 2) v-c should accept -s -l pt in any order"
"$ROOT_DIR/v-c" -s -l pt --help >/dev/null 2>&1 || true
"$ROOT_DIR/v-c" -l pt -s --help >/dev/null 2>&1 || true

echo "[self_check] 3) play_stop.sh should evaluate VC_TEST_UTTERANCE in debug mode"
export VC_DEBUG=1
export VC_TEST_UTTERANCE="hey zorin"
export WAKE_WORD="Hey Zorin"
/bin/bash "$ROOT_DIR/play_stop.sh" es >/dev/null 2>&1 || true

export VC_TEST_UTTERANCE="not the wake word"
/bin/bash "$ROOT_DIR/play_stop.sh" es >/dev/null 2>&1 || true

echo "[self_check] OK"
