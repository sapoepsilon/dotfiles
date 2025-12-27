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
