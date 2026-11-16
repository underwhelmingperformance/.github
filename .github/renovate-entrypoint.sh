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

# Renovate's nix manager installs containerbase's Nix for flake.lock updates.
# Its wrapper in /usr/local/bin comes before /usr/bin/nix in PATH, so any later
# post-upgrade task runs it, and it sets NIX_STORE_DIR and NIX_CONF_DIR to
# directories under the containerbase cache. This configuration in its
# NIX_CONF_DIR gives it the same store and settings as the Nix installed above.
# NIX_STORE_DIR also applies to the substituter, which then refuses
# cache.nixos.org as a cache for another store directory, so the substituter
# URL sets its store directory too.
containerbase_nix_conf_dir=/tmp/containerbase/cache/nix/conf
"${as_renovate_user[@]}" mkdir -p "${containerbase_nix_conf_dir}"
"${as_renovate_user[@]}" tee "${containerbase_nix_conf_dir}/nix.conf" >/dev/null <<'EOF'
include /etc/nix/nix.conf
store = local?store=/nix/store&state=/nix/var/nix&log=/nix/var/log/nix
substituters = https://cache.nixos.org?store=/nix/store
EOF

"${as_renovate_user[@]}" nix --version
"${as_renovate_user[@]}" nix store ping

exec "${as_renovate_user[@]}" renovate
