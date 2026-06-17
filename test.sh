#!/usr/bin/env bash
set -euo pipefail

REGISTRY="http://localhost:55678"
METRICS="http://localhost:55679"
TEST_IMAGE="alpine:latest"

PASS=0
FAIL=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

# ─── Helpers ─────────────────────────────────────────────────────────────────

get_metric() {
  curl -s "$METRICS/metrics" | grep "^$1" | awk '{print $NF}'
}

# ─── Tests ───────────────────────────────────────────────────────────────────

echo ""
echo "▶ Registry health"
if curl -sf "$REGISTRY/v2/" > /dev/null; then
  pass "Registry is reachable at $REGISTRY"
else
  fail "Registry is not reachable at $REGISTRY"
fi

echo ""
echo "▶ Metrics health"
if curl -sf "$METRICS/metrics" > /dev/null; then
  pass "Metrics endpoint reachable at $METRICS/metrics"
else
  fail "Metrics endpoint not reachable at $METRICS/metrics"
fi

echo ""
echo "▶ First pull (expect mirror traffic)"
docker rmi "$TEST_IMAGE" 2>/dev/null || true
MISSES_BEFORE=$(get_metric "registry_proxy_misses_total{type=\"manifest\"}")
HITS_BEFORE=$(get_metric "registry_proxy_hits_total{type=\"manifest\"}")
docker pull "$TEST_IMAGE" -q
MISSES_AFTER=$(get_metric "registry_proxy_misses_total{type=\"manifest\"}")
HITS_AFTER=$(get_metric "registry_proxy_hits_total{type=\"manifest\"}")

if [[ "${MISSES_AFTER:-0}" -gt "${MISSES_BEFORE:-0}" ]]; then
  pass "Cache miss recorded (manifest misses: ${MISSES_BEFORE:-0} → ${MISSES_AFTER:-0})"
elif [[ "${HITS_AFTER:-0}" -gt "${HITS_BEFORE:-0}" ]]; then
  pass "Cache hit recorded — image already in mirror (manifest hits: ${HITS_BEFORE:-0} → ${HITS_AFTER:-0})"
else
  fail "Expected mirror traffic (misses: ${MISSES_BEFORE:-0} → ${MISSES_AFTER:-0}, hits: ${HITS_BEFORE:-0} → ${HITS_AFTER:-0})"
fi

echo ""
echo "▶ Second pull (expect hits)"
docker rmi "$TEST_IMAGE" 2>/dev/null || true
HITS_BEFORE=$(get_metric "registry_proxy_hits_total{type=\"blob\"}")
docker pull "$TEST_IMAGE" -q
HITS_AFTER=$(get_metric "registry_proxy_hits_total{type=\"blob\"}")

if [[ "${HITS_AFTER:-0}" -gt "${HITS_BEFORE:-0}" ]]; then
  pass "Cache hit recorded (blob hits: ${HITS_BEFORE:-0} → ${HITS_AFTER:-0})"
else
  fail "Expected hits to increase (before: ${HITS_BEFORE:-0}, after: ${HITS_AFTER:-0})"
fi

echo ""
echo "▶ Cleanup"
docker rmi "$TEST_IMAGE" 2>/dev/null && pass "Test image removed" || pass "Image already removed"

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────"
echo "  Passed: $PASS  Failed: $FAIL"
echo "────────────────────────────────"
echo ""

[[ $FAIL -eq 0 ]]