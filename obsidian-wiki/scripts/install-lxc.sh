#!/usr/bin/env bash
# Bootstrap a Proxmox LXC (or any Debian/Ubuntu host) as a remote MCP endpoint
# for the LLM wiki vault. After running this, any agent on your LAN can connect
# to http://<lxc-ip>:9876/servers/vault-fs/sse and read/write the vault.
#
# Prerequisites:
#   - Debian 12 or Ubuntu 24.04, root access
#   - LXC features: nesting=1, fuse=1 (or run on a VM where FUSE is unrestricted)
#   - You have an existing rclone remote called 'gdrive' configured (run
#     `rclone config` and complete OAuth before invoking this script)
#
# Usage (on the LXC):
#   curl -sL https://raw.githubusercontent.com/sapoepsilon/dotfiles/main/obsidian-wiki/scripts/install-lxc.sh | bash
#
# Or run from a clone:
#   git clone https://github.com/sapoepsilon/dotfiles ~/dotfiles
#   bash ~/dotfiles/obsidian-wiki/scripts/install-lxc.sh

set -euo pipefail

VAULT_REMOTE_PATH="${VAULT_REMOTE_PATH:-/mnt/vault/llm-vault}"
SYSTEMD_DIR=/etc/systemd/system
DOTFILES_RAW="https://raw.githubusercontent.com/sapoepsilon/dotfiles/main/obsidian-wiki"

echo "=== Installing dependencies ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates fuse3 python3 python3-pip pipx git rclone

echo "--- Node 20 ---"
if ! command -v node >/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
  apt-get install -y -qq nodejs
fi

echo "--- mcp-proxy + filesystem MCP server ---"
pipx install mcp-proxy 2>&1 | tail -1
pipx ensurepath >/dev/null 2>&1
npm install -g @modelcontextprotocol/server-filesystem 2>&1 | tail -1

echo ""
echo "=== Verifying rclone remote ==="
if ! rclone listremotes | grep -q '^gdrive:'; then
  echo ""
  echo "ERROR: no rclone remote named 'gdrive' is configured."
  echo "Run 'rclone config' first, name the remote 'gdrive', complete OAuth."
  exit 1
fi
echo "  found: gdrive:"

echo ""
echo "=== Installing systemd units ==="
curl -fsSL "$DOTFILES_RAW/systemd/rclone-vault.service" -o "$SYSTEMD_DIR/rclone-vault.service"
curl -fsSL "$DOTFILES_RAW/systemd/mcp-vault-fs.service" -o "$SYSTEMD_DIR/mcp-vault-fs.service"
systemctl daemon-reload
systemctl enable --now rclone-vault.service
sleep 5
if ! mountpoint -q /mnt/vault; then
  echo "ERROR: rclone-vault failed to mount. Check: journalctl -u rclone-vault -n 50"
  exit 1
fi
ls -la "$VAULT_REMOTE_PATH" >/dev/null || {
  echo "ERROR: vault path not visible at $VAULT_REMOTE_PATH"
  echo "Verify the path matches your Drive layout."
  exit 1
}
systemctl enable --now mcp-vault-fs.service

echo ""
echo "=== Smoke test: HTTP MCP endpoint ==="
sleep 3
LXC_IP=$(ip -4 -o addr show eth0 | awk '{print $4}' | cut -d/ -f1)
if curl -fsS "http://127.0.0.1:9876/servers/vault-fs/sse" --max-time 3 >/dev/null 2>&1 || \
   curl -fsS "http://127.0.0.1:9876/" --max-time 3 -o /dev/null; then
  echo "  ✓ MCP server responding on :9876"
else
  echo "  ⚠  MCP server not yet responding. Check: journalctl -u mcp-vault-fs -n 50"
fi

echo ""
echo "=== Done ==="
echo ""
echo "Endpoint: http://${LXC_IP}:9876/servers/vault-fs/sse"
echo ""
echo "Add to any MCP client (Claude Code/Desktop) as an mcpServer entry:"
echo '  {'
echo '    "command": "npx",'
echo "    \"args\": [\"-y\", \"mcp-remote\", \"http://${LXC_IP}:9876/servers/vault-fs/sse\"]"
echo '  }'
