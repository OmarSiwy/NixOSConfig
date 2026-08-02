#!/usr/bin/env bash
# Wipes Claude Code's local state: synced skills, session transcripts, caches.
#
# Kept: ~/.claude/settings.json, .credentials.json, projects/*/memory/, and the
# plugin manifests (installed_plugins.json, known_marketplaces.json).
# Run update_dots.sh afterwards to re-sync skills from this repo.
#
#   ./clear_claude_skills.sh            # skills + sessions + caches
#   ./clear_claude_skills.sh --plugins  # also drop plugins/cache (re-cloned on next start)
set -eu

C="$HOME/.claude"
[ -d "$C" ] || { echo "No $C, nothing to do"; exit 0; }

before=$(du -sh "$C" | cut -f1)

rm -rf "$C/skills"

# Session/runtime state. paste-cache and shell-snapshots are pure scratch;
# plans/tasks/teams are per-session records.
rm -rf "$C"/cache "$C"/paste-cache "$C"/shell-snapshots "$C"/file-history \
       "$C"/session-env "$C"/sessions "$C"/telemetry "$C"/backups \
       "$C"/plans "$C"/tasks "$C"/teams "$C"/history.jsonl

# Transcripts live directly under projects/<slug>/. memory/ lives there too and
# holds the persistent per-project memories, so keep it.
if [ -d "$C/projects" ]; then
    for p in "$C"/projects/*/; do
        [ -d "$p" ] || continue
        find "$p" -mindepth 1 -maxdepth 1 ! -name memory -exec rm -rf {} +
    done
fi

if [ "${1:-}" = "--plugins" ]; then
    rm -rf "$C/plugins/cache"
fi

echo "Cleared $C: $before -> $(du -sh "$C" | cut -f1)"
echo "Run ./update_dots.sh to re-sync skills."
