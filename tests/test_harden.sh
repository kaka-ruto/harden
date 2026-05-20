#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HARDEN="$SCRIPT_DIR/bin/harden"
CONTAINER="harden-test-$$"

PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo -e "  \033[0;32m✓ $1\033[0m"; }
fail() { FAIL=$((FAIL+1)); echo -e "  \033[0;31m✗ $1\033[0m"; }

cleanup() { docker rm -f "$CONTAINER" 2>/dev/null || true; }
trap cleanup EXIT

echo "═══════════════════════════════════════════"
echo "  harden — Integration Tests"
echo "═══════════════════════════════════════════"

# ── Setup: run the init inline to ensure packages install before we test ──
echo ""
echo "--- Setting up test container ---"

# Use a Dockerfile approach: build a container with everything ready
cat > /tmp/harden_test.dockerfile << 'DFILE'
FROM ubuntu:24.04
RUN apt update -qq && DEBIAN_FRONTEND=noninteractive apt install -y -qq openssh-server ufw docker.io >/dev/null 2>&1 && \
    mkdir -p /run/sshd
COPY bin/harden /usr/local/bin/harden
RUN chmod +x /usr/local/bin/harden
CMD ["bash", "-c", "/usr/sbin/sshd && while true; do sleep 30; done"]
DFILE

docker build -q -t harden-test-image -f /tmp/harden_test.dockerfile "$SCRIPT_DIR" > /dev/null
echo "Image built"

docker run -d --name "$CONTAINER" --privileged harden-test-image > /dev/null
echo "Container started, waiting..."
sleep 2

# Verify packages are installed
docker exec "$CONTAINER" bash -c "
  echo '=== Verifying installed packages ==='
  for pkg in openssh-server ufw docker.io; do
    dpkg -l \$pkg 2>/dev/null | grep -q '^ii' && echo \"  ✓ \$pkg\" || echo \"  ✗ \$pkg\"
  done
" 2>&1

# ── Test 1: Check mode ──
echo ""
echo "--- Test 1: Check mode ---"
docker exec "$CONTAINER" harden --local --check > /tmp/harden_check.log 2>&1 || true
if grep -q "\[fail\]" /tmp/harden_check.log; then
  pass "Check mode detected issues"
else
  fail "Check mode should detect issues"
fi

# ── Test 2: Run hardening ──
echo ""
echo "--- Test 2: Running hardening ---"
docker exec "$CONTAINER" harden --local > /tmp/harden_fix.log 2>&1 || true
# Show what happened
grep -E "\[ok\]|\[fail\]" /tmp/harden_fix.log || echo "(no ok/fail lines)"
echo ""
echo "Waiting for services..."
sleep 3

# ── Test 3: Verify UFW ──
echo "--- Test 3: UFW ---"
docker exec "$CONTAINER" bash -c "ufw status | head -1 | grep -qi active" 2>/dev/null && pass "UFW active" || {
  # Check if ufw exists at all
  docker exec "$CONTAINER" bash -c "command -v ufw" 2>/dev/null && fail "UFW should be active" || fail "UFW not installed"
}

# ── Test 4: SSH config (check config file, not sshd -T which needs full boot) ──
echo "--- Test 4: SSH ---"
docker exec "$CONTAINER" bash -c "grep -q 'PermitRootLogin prohibit-password' /etc/ssh/sshd_config" && pass "SSH root key-only" || fail "SSH root key-only"
docker exec "$CONTAINER" bash -c "grep -q 'PasswordAuthentication no' /etc/ssh/sshd_config" && pass "SSH passwords disabled" || fail "SSH passwords disabled"
docker exec "$CONTAINER" bash -c "grep -q 'KbdInteractiveAuthentication no' /etc/ssh/sshd_config" && pass "SSH kbd-interactive disabled" || fail "SSH kbd-interactive disabled"

# ── Test 5: Docker config ──
echo "--- Test 5: Docker ---"
docker exec "$CONTAINER" bash -c "test -f /etc/docker/daemon.json" && pass "Docker daemon.json exists" || fail "Docker daemon.json"
docker exec "$CONTAINER" bash -c "grep -q 'icc.*false' /etc/docker/daemon.json 2>/dev/null" && pass "Docker icc disabled" || fail "Docker icc"
docker exec "$CONTAINER" bash -c "grep -q 'log-opts' /etc/docker/daemon.json 2>/dev/null" && pass "Docker logs limited" || fail "Docker logs"

# ── Test 6: fail2ban ──
echo "--- Test 6: fail2ban ---"
docker exec "$CONTAINER" bash -c "dpkg -l fail2ban 2>/dev/null | grep -q '^ii'" && pass "fail2ban installed" || fail "fail2ban"

# ── Test 7: telnet ──
echo "--- Test 7: telnet ---"
docker exec "$CONTAINER" bash -c "! dpkg -l inetutils-telnet 2>/dev/null | grep -q '^ii'" && pass "telnet not present" || fail "telnet"

# ── Test 8: unattended-upgrades ──
echo "--- Test 8: unattended-upgrades ---"
docker exec "$CONTAINER" bash -c "dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii'" && pass "unattended-upgrades installed" || fail "unattended-upgrades"

# ── Test 9: Idempotency ──
echo ""
echo "--- Test 9: Idempotent re-run ---"
docker exec "$CONTAINER" harden --local > /tmp/harden_rerun.log 2>&1 || true
if grep -q "\[fail\]" /tmp/harden_rerun.log; then
  fail "Re-run should not produce failures"
else
  pass "Idempotent re-run OK"
fi

echo ""
echo "═══ Results: ${PASS} passed, ${FAIL} failed ═══"
[ "$FAIL" -eq 0 ] || exit 1
