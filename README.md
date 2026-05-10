# Dotfiles

Personal configuration files and scripts.

## Claude Code Skills

Custom skills for Claude Code CLI are located in `claude/skills/`.

### Installation

To install skills on a new machine, symlink or copy to `~/.claude/skills/`:

```bash
# Option 1: Symlink (recommended - stays in sync with repo)
ln -s $(pwd)/claude/skills/* ~/.claude/skills/

# Option 2: Copy
cp -r claude/skills/* ~/.claude/skills/
```

### Available Skills

- **r2** - Cloudflare R2 object storage management via Wrangler CLI

## obsidian-wiki

Multi-agent LLM Wiki setup based on Karpathy's pattern. Mac runs Obsidian + skills; an optional Proxmox LXC exposes the same vault as an HTTP/SSE MCP endpoint so any remote agent (Hermes, OpenClaw, second laptop, mobile) can read and write it.

See [`obsidian-wiki/README.md`](obsidian-wiki/README.md) for architecture, install, MCP client snippets, and the trust posture.

```bash
# Mac side
OBSIDIAN_VAULT_PATH=~/path/to/vault bash obsidian-wiki/scripts/install-mac.sh

# Proxmox LXC side (after `rclone config` with remote name 'gdrive')
curl -sL https://raw.githubusercontent.com/sapoepsilon/dotfiles/main/obsidian-wiki/scripts/install-lxc.sh | bash
```
