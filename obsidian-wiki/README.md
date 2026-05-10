# obsidian-wiki

A multi-agent LLM Wiki setup based on [Karpathy's pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) on top of the [Ar9av/obsidian-wiki](https://github.com/Ar9av/obsidian-wiki) skill framework.

The vault lives in Obsidian on Mac. Any LLM agent — Claude Code, Claude Desktop, Hermes Agent, OpenClaw, or anything else that speaks MCP — can read and write it.

## Architecture

```
┌─────────────────── Mac (primary writer) ────────────────────┐
│  ~/.../GoogleDrive-.../My Drive/llm-vault/                  │
│   ├── raw/      ← immutable sources                         │
│   ├── _raw/     ← staging dropbox                           │
│   ├── wiki/     ← LLM-maintained pages with [[wikilinks]]   │
│   ├── _meta/, _archive/                                     │
│   └── CLAUDE.md, AGENTS.md, index.md, log.md, hot.md        │
│                                                             │
│  Writers (filesystem-direct via the Drive mount):           │
│   • Claude Code   — 25 skills via ~/.claude/skills/         │
│   • Claude Desktop — mcp-obsidian → Local REST API plugin   │
│   • Obsidian app   — viewer + Local REST API on :27124      │
└─────────────────────────────────────────────────────────────┘
                       ↑ HTTP/SSE on LAN
┌──────────── Proxmox LXC obsidian-bridge ────────────────────┐
│  rclone mount of the same Drive (RW) at /mnt/vault          │
│  Vault sits at /mnt/vault/llm-vault (rclone treats Drive    │
│  root as mount root — no "My Drive" subdir intermediate)    │
│  mcp-proxy on :9876                                         │
│   └─ vault-fs (filesystem MCP server) under /servers/vault-fs/sse │
│                                                             │
│  Any remote agent connects via:                             │
│    npx mcp-remote http://<lxc-ip>:9876/servers/vault-fs/sse │
└─────────────────────────────────────────────────────────────┘
```

## Install

### Mac side

```bash
OBSIDIAN_VAULT_PATH="$HOME/Library/CloudStorage/GoogleDrive-you@example.com/My Drive/llm-vault" \
  bash scripts/install-mac.sh
```

What it does:

1. Clones `Ar9av/obsidian-wiki` to `~/.obsidian-wiki/repo/` and pins to commit `6e8461668c39a0d3ea25b6e007f29728ca4ba3c5` (the May 9, 2026 release)
2. **Removes 6 history-ingest skills** before install — these read your full Claude/Codex/Hermes/OpenClaw conversation transcripts and would mine them into the vault. Privacy-sensitive enough to warrant explicit opt-in if you want them later
3. Writes the framework `.env` with your vault path
4. Symlinks the remaining 25 skills into every supported agent's skill directory (`~/.claude/skills/`, `~/.hermes/skills/`, `~/.openclaw/skills/`, `~/.codex/skills/`, etc.)

You still need to manually:

- Install Obsidian: https://obsidian.md/download
- Install the **Local REST API** community plugin (required for Claude Desktop's MCP)
- Install the Obsidian Web Clipper browser extension (set destination to `raw/articles/`)
- Patch your Claude Desktop / Claude Code MCP configs — see `mcp/claude_desktop.example.json` and `mcp/claude_code.example.json`

### Proxmox LXC side (for remote-agent access)

Create a Debian/Ubuntu LXC with these features (via Proxmox UI or `pct create`):

```bash
pct create <vmid> local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname obsidian-bridge \
  --cores 2 --memory 2048 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --rootfs local-lvm:10 \
  --features nesting=1,fuse=1 \
  --unprivileged 0 \
  --onboot 1 \
  --ssh-public-keys /root/.ssh/authorized_keys
pct start <vmid>
```

Inside the LXC, configure rclone first (interactive OAuth):

```bash
rclone config
# Walk through:
#   n - new remote
#   name: gdrive
#   storage: drive (Google Drive)
#   client_id, client_secret: blank
#   scope: 1 (Full access)
#   service_account_file: blank
#   advanced config: n
#   auto config: n  ← critical, you're headless
#   Open the printed URL on a machine with a browser, paste the resulting token
#   Shared Drive: n
```

Then bootstrap the MCP services:

```bash
curl -sL https://raw.githubusercontent.com/sapoepsilon/dotfiles/main/obsidian-wiki/scripts/install-lxc.sh | bash
```

What that script does:

1. Installs rclone, Node 20, mcp-proxy, `@modelcontextprotocol/server-filesystem`
2. Drops the systemd units from `systemd/` into `/etc/systemd/system/`
3. Mounts the Drive RW at `/mnt/vault` via the `rclone-vault.service`
4. Starts `mcp-vault-fs.service` — exposes the vault as an HTTP/SSE MCP server on `:9876`

Verify from another machine:

```bash
curl -i http://<lxc-ip>:9876/servers/vault-fs/sse
# Should hold the connection open with Content-Type: text/event-stream
```

### MCP client config — connect any agent

Pick the snippet from `mcp/`:

- `mcp/claude_code.example.json` — entries to merge into `~/.claude.json` under `mcpServers`
- `mcp/claude_desktop.example.json` — entries to merge into `~/Library/Application Support/Claude/claude_desktop_config.json`

Each example shows three flavors of access:

| Server name | What it does | When to use |
|---|---|---|
| `obsidian-local` | Talks to Obsidian's Local REST API plugin on the Mac | Best when you want operations to update the Obsidian UI live |
| `filesystem-vault-local` | Direct filesystem access to the Mac's Drive mount | Lightest weight; doesn't need Obsidian app running |
| `vault-fs-remote` | Talks to the Proxmox LXC over HTTP/SSE | Required for any agent NOT on this Mac (Hermes, OpenClaw, mobile, second laptop) |

You can have all three configured — they don't conflict. Pick whichever endpoint is appropriate for the operation.

## Trust posture

Three rules that should survive any future upgrade:

1. **Pin the framework commit.** `Ar9av/obsidian-wiki` is a 1-month-old project with a small maintainer. Skills are instructions the LLM executes — a malicious upstream PR could exfiltrate vault contents silently. Re-read upstream diffs before advancing the pinned SHA.
2. **History-ingest skills stay out by default.** They read entire conversation transcripts and turn them into wiki pages. Easy way to land secrets in your knowledge base. Add them deliberately, per-skill, only after you've reviewed what they'd ingest.
3. **One filesystem writer at a time.** Both Mac (Drive native client) and LXC (rclone) can write to the same vault. If you ever extend write access to multiple machines simultaneously, expect Drive to produce `.gdoc`-style conflict files. Coordinate writes or shard the vault.

## Layout reference

```
obsidian-wiki/
├── README.md                          ← this file
├── scripts/
│   ├── install-mac.sh                 ← Mac bootstrap (sets PINNED_SHA, strips skills, runs setup)
│   └── install-lxc.sh                 ← LXC bootstrap (assumes rclone gdrive remote exists)
├── systemd/
│   ├── rclone-vault.service           ← FUSE mount of gdrive: at /mnt/vault
│   └── mcp-vault-fs.service           ← mcp-proxy + filesystem MCP on :9876
└── mcp/
    ├── claude_code.example.json       ← merge into ~/.claude.json mcpServers
    └── claude_desktop.example.json    ← merge into Claude Desktop config
```

## Uninstall

Mac:
```bash
find ~/.claude ~/.hermes ~/.openclaw ~/.codex ~/.copilot ~/.gemini ~/.kiro \
     ~/.agents ~/.trae ~/.trae-cn ~/.cursor ~/.windsurf -maxdepth 3 \
     -lname '*obsidian-wiki*' -delete 2>/dev/null
rm -rf ~/.obsidian-wiki
# Remove "mcpServers" entries from ~/.claude.json and Claude Desktop config
# Vault content stays put on Drive — delete manually if you want
```

LXC:
```bash
systemctl disable --now mcp-vault-fs.service rclone-vault.service
rm /etc/systemd/system/{rclone-vault,mcp-vault-fs}.service
systemctl daemon-reload
fusermount3 -u /mnt/vault 2>/dev/null
# Then on Proxmox host:
pct stop <vmid> && pct destroy <vmid>
```
