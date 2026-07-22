#!/usr/bin/env bash
bash $HOME/Documents/Desktop/nixos/dotfiles/river/scripts/reloadconfig.sh

REPO_DIR="$HOME/Documents/Desktop/nixos"
rm -rf "$HOME/.claude/skills"
mkdir -p "$HOME/.claude/skills"
# Flatten: skill_repo uses category dirs (dod/, engineering/, etc.)
# but Claude Code needs skills/<name>/SKILL.md (one level deep)
count=0
for skill in "$REPO_DIR/skills"/*/*; do
    [ -d "$skill" ] && [ -f "$skill/SKILL.md" ] || continue
    cp -r "$skill" "$HOME/.claude/skills/$(basename "$skill")"
    count=$((count + 1))
done
echo "Synced $count skills -> $HOME/.claude/skills"
