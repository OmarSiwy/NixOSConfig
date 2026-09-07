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

# Share the same skills with Codex (same SKILL.md format, different dir).
# Per-skill symlinks, not a dir symlink: Codex owns ~/.codex/skills/.system
# and recreates it on every launch.
if [ -d "$HOME/.codex" ]; then
    mkdir -p "$HOME/.codex/skills"
    find "$HOME/.codex/skills" -maxdepth 1 -xtype l -delete  # prune dangling
    for skill in "$HOME/.claude/skills"/*/; do
        ln -sfn "${skill%/}" "$HOME/.codex/skills/$(basename "$skill")"
    done
    echo "Linked $count skills -> $HOME/.codex/skills"
fi
