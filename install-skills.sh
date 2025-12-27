#!/bin/bash
# Install Claude Code skills from this repo
# Usage: curl -sL https://raw.githubusercontent.com/sapoepsilon/dotfiles/main/install-skills.sh | bash

REPO_URL="https://raw.githubusercontent.com/sapoepsilon/dotfiles/main"

echo "Installing Claude Code skills..."

# R2 skill
mkdir -p ~/.claude/skills/r2
curl -sL "$REPO_URL/claude/skills/r2/SKILL.md" -o ~/.claude/skills/r2/SKILL.md
curl -sL "$REPO_URL/claude/skills/r2/REFERENCE.md" -o ~/.claude/skills/r2/REFERENCE.md

echo "Done! Installed skills:"
ls -la ~/.claude/skills/
