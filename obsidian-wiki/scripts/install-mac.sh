#!/usr/bin/env bash
# Mac side bootstrap for Karpathy LLM Wiki on top of Ar9av/obsidian-wiki framework.
#
# What this does:
#   1. Clones obsidian-wiki at a pinned commit
#   2. Removes 6 history-ingest skills (privacy guard — they read conversation transcripts)
#   3. Writes the framework .env pointing at the vault you specify
#   4. Symlinks the remaining 25 skills into every supported agent's skills dir
#
# What this does NOT do (manual steps remain):
#   - Install Obsidian app
#   - Install the "Local REST API" community plugin
#   - Patch your Claude Desktop / Claude Code MCP configs (see ../mcp/*.example.json)
#
# Usage:
#   OBSIDIAN_VAULT_PATH=~/Library/CloudStorage/GoogleDrive-you@example.com/My\ Drive/llm-vault \
#     bash install-mac.sh

set -euo pipefail

PINNED_SHA="${PINNED_SHA:-6e8461668c39a0d3ea25b6e007f29728ca4ba3c5}"
FRAMEWORK_DIR="${FRAMEWORK_DIR:-$HOME/.obsidian-wiki/repo}"
VAULT_PATH="${OBSIDIAN_VAULT_PATH:-}"

if [[ -z "$VAULT_PATH" ]]; then
  echo "ERROR: set OBSIDIAN_VAULT_PATH before running."
  echo "Example:"
  echo "  OBSIDIAN_VAULT_PATH=~/vault bash $0"
  exit 1
fi

if [[ ! -d "$VAULT_PATH" ]]; then
  echo "Vault path does not exist; creating: $VAULT_PATH"
  mkdir -p "$VAULT_PATH"/{raw/{articles,transcripts,notes,pdfs,exports},_raw,wiki,_meta,_archive}
fi

echo "=== Cloning Ar9av/obsidian-wiki (pinned $PINNED_SHA) ==="
mkdir -p "$(dirname "$FRAMEWORK_DIR")"
if [[ -d "$FRAMEWORK_DIR/.git" ]]; then
  cd "$FRAMEWORK_DIR" && git fetch --quiet
else
  git clone --quiet https://github.com/Ar9av/obsidian-wiki "$FRAMEWORK_DIR"
  cd "$FRAMEWORK_DIR"
fi
git checkout --quiet --detach "$PINNED_SHA"
echo "  pinned at $(git rev-parse HEAD)"

echo ""
echo "=== Removing privacy-sensitive history-ingest skills ==="
cd "$FRAMEWORK_DIR/.skills"
for s in claude-history-ingest codex-history-ingest copilot-history-ingest \
         hermes-history-ingest openclaw-history-ingest wiki-history-ingest; do
  if [[ -d "$s" ]]; then
    rm -rf "$s"
    echo "  removed: $s"
  fi
done
echo "  remaining skills: $(ls -d */ | wc -l | tr -d ' ')"

echo ""
echo "=== Writing framework .env ==="
cat > "$FRAMEWORK_DIR/.env" <<EOF
OBSIDIAN_VAULT_PATH="$VAULT_PATH"
OBSIDIAN_SOURCES_DIR=
OBSIDIAN_CATEGORIES=concepts,entities,skills,references,synthesis,journal
OBSIDIAN_MAX_PAGES_PER_INGEST=15
LINT_SCHEDULE=weekly
OBSIDIAN_LINK_FORMAT=wikilink
OBSIDIAN_RAW_DIR=_raw
QMD_WIKI_COLLECTION=
QMD_PAPERS_COLLECTION=
EOF

echo ""
echo "=== Running framework setup ==="
cd "$FRAMEWORK_DIR"
bash setup.sh

echo ""
echo "=== Done ==="
echo ""
echo "Next steps:"
echo "  1. Install Obsidian: https://obsidian.md/download"
echo "  2. Install the 'Local REST API' community plugin"
echo "  3. Patch your Claude Desktop / Claude Code MCP configs from ../mcp/*.example.json"
echo "  4. Smoke test: cd anywhere, run 'claude', type '/wiki-update'"
