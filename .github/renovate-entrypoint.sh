#!/bin/bash

# Renovate runs post-upgrade tasks inside this container. Repositories such as
# cupboard build a flake derivation in those tasks to resolve a pinned pnpm
# store hash, which needs a usable Nix. containerbase's bundled Nix keeps its
# store under the cache directory, not /nix/store; because Nix addresses store
# paths by the store directory, cache.nixos.org cannot serve them and builds
# compile the whole toolchain from source. Installing a real Nix here gives the
# tasks a /nix/store that substitutes the toolchain from cache.nixos.org.

set -euo pipefail

echo "Installing Nix..."
apt-get update
apt-get install --yes --no-install-recommends nix-bin

mkdir -p /etc/nix
cat >/etc/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
substituters = https://cache.nixos.org

# Build as the calling user: this ephemeral container has no nixbld group.
build-users-group =

# The container cannot create the namespaces the build sandbox needs.
sandbox = false

max-jobs = auto
EOF

nix --version

exec renovate
