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

# The container cannot create the namespaces the build sandbox needs.
sandbox = false

max-jobs = auto
EOF

# Nix uses /nix/store only when /nix/var/nix exists and is writable. Without
# that directory, Nix gives a user other than root a store under
# ~/.local/share/nix/root instead.
mkdir -p /nix/var/nix
chown -R ubuntu:root /nix

# The image's user has root (gid 0) as its primary group, and Docker gives it
# the same groups when the image starts without a `--user` override.
as_renovate_user=(setpriv --reuid=ubuntu --regid=root --init-groups --no-new-privs)
export HOME=/home/ubuntu

"${as_renovate_user[@]}" nix --version
"${as_renovate_user[@]}" nix store ping

exec "${as_renovate_user[@]}" renovate
