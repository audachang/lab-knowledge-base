#!/bin/bash
# Fix apt-get issues with NeuroDebian and Antigravity repos on Ubuntu Noble (24.04)
#
# Problems:
#   1. NeuroDebian: weak dsa1024 key warning from duplicate keys in trusted.gpg.d
#   2. Antigravity: missing GPG key + rsa2048 rejected by Noble's default >=rsa3072 policy
#
# Applies to: Ubuntu 24.04 (Noble) servers with neurodebian and antigravity repos
# First fixed on: braina-aclexp — 2026-04-10
#
# Usage:
#   sudo bash fix-apt-neurodebian-antigravity.sh
#   # or remotely:
#   ssh root@<host> 'bash -s' < fix-apt-neurodebian-antigravity.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: must run as root (use sudo)" >&2
  exit 1
fi

echo "=== Fixing apt repo issues for NeuroDebian and Antigravity ==="

# --- NeuroDebian: remove redundant keys from trusted.gpg.d ---
# neurodebian.sources already uses Signed-By:/etc/apt/keyrings/neurodebian.gpg,
# so keys in trusted.gpg.d are redundant and trigger weak-algorithm warnings.
if ls /etc/apt/trusted.gpg.d/neurodebian* &>/dev/null; then
  rm -f /etc/apt/trusted.gpg.d/neurodebian*
  echo "[neurodebian] Removed redundant keys from trusted.gpg.d"
else
  echo "[neurodebian] No redundant keys in trusted.gpg.d — skipped"
fi

# Update neurodebian keyring with both old (dsa1024) and new (rsa4096) keys
if [ -f /etc/apt/keyrings/neurodebian.gpg ]; then
  TMPRING=$(mktemp /tmp/neuro-keyring.XXXXXX.gpg)
  cp /etc/apt/keyrings/neurodebian.gpg "$TMPRING"

  # Fetch the new rsa4096 key (1F42AA2C) if not already present
  if ! gpg --no-default-keyring --keyring "$TMPRING" --list-keys 439754ED1F42AA2C &>/dev/null 2>&1; then
    gpg --no-default-keyring --keyring "$TMPRING" \
      --keyserver keyserver.ubuntu.com --recv-keys 439754ED1F42AA2C 2>/dev/null || true
    cp "$TMPRING" /etc/apt/keyrings/neurodebian.gpg
    chmod 644 /etc/apt/keyrings/neurodebian.gpg
    echo "[neurodebian] Added new rsa4096 key to keyring"
  else
    echo "[neurodebian] Keyring already has new rsa4096 key — skipped"
  fi
  rm -f "$TMPRING"
else
  echo "[neurodebian] No keyring at /etc/apt/keyrings/neurodebian.gpg — skipped"
fi

# --- Antigravity: install GPG key and convert to deb822 format ---
if [ -f /etc/apt/sources.list.d/antigravity.list ]; then
  # Fetch signing key
  mkdir -p /etc/apt/keyrings
  gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/keyrings/antigravity.gpg \
    --keyserver keyserver.ubuntu.com --recv-keys C0BA5CE6DC6315A3 2>/dev/null
  chmod 644 /etc/apt/keyrings/antigravity.gpg

  # Convert to deb822 format with Signed-By
  cat > /etc/apt/sources.list.d/antigravity.sources <<'EOF'
Types: deb
URIs: https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/
Suites: antigravity-debian
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/antigravity.gpg
EOF
  rm /etc/apt/sources.list.d/antigravity.list
  echo "[antigravity] Installed GPG key and converted to deb822 format"
elif [ -f /etc/apt/sources.list.d/antigravity.sources ]; then
  echo "[antigravity] Already in deb822 format — skipped conversion"
else
  echo "[antigravity] No antigravity source found — skipped"
fi

# --- Fix weak-key policy: allow rsa2048 (antigravity uses rsa2048 signing key) ---
POLICY_FILE="/etc/apt/apt.conf.d/99-weak-key-algo"
if [ -f "$POLICY_FILE" ] && grep -q '>=rsa3072' "$POLICY_FILE"; then
  sed -i 's/>=rsa3072/>=rsa2048/' "$POLICY_FILE"
  echo "[policy] Relaxed key policy from rsa3072 to rsa2048"
elif [ -f "$POLICY_FILE" ]; then
  echo "[policy] Already allows rsa2048 — skipped"
else
  echo "[policy] No $POLICY_FILE found — skipped"
fi

# --- Verify ---
echo ""
echo "=== Running apt-get update ==="
if apt-get update 2>&1 | grep -iE '^(E:|W:)'; then
  echo "WARNING: apt-get update still has issues (see above)"
  exit 1
else
  echo "apt-get update completed cleanly"
fi
