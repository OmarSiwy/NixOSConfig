#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

freed_total=0

log() { echo -e "${CYAN}::${NC} $1"; }
ok() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
skip() { echo -e "  ${YELLOW}skipped (dry-run)${NC}"; }

bytes_to_human() {
    local bytes=$1
    if ((bytes >= 1073741824)); then
        printf "%.1fG" "$(echo "$bytes / 1073741824" | bc -l)"
    elif ((bytes >= 1048576)); then
        printf "%.1fM" "$(echo "$bytes / 1048576" | bc -l)"
    elif ((bytes >= 1024)); then
        printf "%.1fK" "$(echo "$bytes / 1024" | bc -l)"
    else
        printf "%dB" "$bytes"
    fi
}

dir_size_bytes() {
    du -sb "$1" 2>/dev/null | cut -f1 || echo 0
}

clean_dir() {
    local dir="$1"
    local label="$2"
    if [[ -d "$dir" ]]; then
        local size
        size=$(dir_size_bytes "$dir")
        if ((size > 0)); then
            if $DRY_RUN; then
                log "$label: $(bytes_to_human "$size") reclaimable"
                skip
            else
                rm -rf "${dir:?}"/*
                freed_total=$((freed_total + size))
                ok "$label: freed $(bytes_to_human "$size")"
            fi
        fi
    fi
}

echo -e "\n${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       NixOS Cleanup Script           ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}\n"

$DRY_RUN && echo -e "${YELLOW}DRY RUN — nothing will be deleted${NC}\n"

# ─── 1. Nix store garbage collection ───────────────────────────────────────────

log "Nix store: collecting garbage (older than 3d)..."
nix_before=$(dir_size_bytes /nix/store)
if $DRY_RUN; then
    dead=$(nix-store --gc --print-dead 2>/dev/null | wc -l)
    warn "$dead dead store paths would be removed"
    skip
else
    sudo nix-collect-garbage -d 2>&1 | tail -1
    nix-collect-garbage -d 2>&1 | tail -1
    nix_after=$(dir_size_bytes /nix/store)
    nix_freed=$((nix_before - nix_after))
    ((nix_freed > 0)) && freed_total=$((freed_total + nix_freed))
    ok "Nix store: freed $(bytes_to_human $nix_freed)"
fi

# ─── 2. Deduplicate nix store (hard-links identical files) ─────────────────────

log "Optimising nix store (dedup via hard-links)..."
if $DRY_RUN; then
    skip
else
    nix store optimise 2>&1 | tail -3
    ok "Store optimised"
fi

# ─── 3. Old system & home-manager generations ─────────────────────────────────

log "Pruning old NixOS system profiles..."
if $DRY_RUN; then
    count=$(ls /nix/var/nix/profiles/system-*-link 2>/dev/null | wc -l)
    warn "$count system profile links present"
    skip
else
    sudo nix-env --delete-generations +2 -p /nix/var/nix/profiles/system 2>/dev/null || true
    ok "System profiles trimmed to last 2"
fi

if command -v home-manager &>/dev/null; then
    log "Pruning old home-manager generations..."
    if $DRY_RUN; then
        skip
    else
        home-manager expire-generations "-3 days" 2>/dev/null || true
        ok "Home-manager generations pruned"
    fi
fi

# ─── 4. User caches ───────────────────────────────────────────────────────────

echo ""
log "Cleaning user caches..."

clean_dir "$HOME/.cache/spotify/Data" "Spotify cache"
clean_dir "$HOME/.cache/uv" "uv (Python) cache"
clean_dir "$HOME/.cache/qutebrowser" "Qutebrowser cache"
clean_dir "$HOME/.cache/mozilla/firefox" "Firefox cache"
clean_dir "$HOME/.cache/pip" "pip cache"
clean_dir "$HOME/.cache/zig" "Zig cache"
clean_dir "$HOME/.cache/ccache" "ccache"
clean_dir "$HOME/.cache/wine" "Wine cache"
clean_dir "$HOME/.cache/mesa_shader_cache" "Mesa shader cache"
clean_dir "$HOME/.cache/nix" "Nix eval cache"
clean_dir "$HOME/.cache/Tectonic" "Tectonic cache"
clean_dir "$HOME/.cache/clangd" "clangd cache"
clean_dir "$HOME/.cache/typescript" "TypeScript cache"
clean_dir "$HOME/.cache/fontconfig" "Fontconfig cache"
clean_dir "$HOME/.cache/thumbnails" "Thumbnails"
clean_dir "$HOME/.cache/qtshadercache-x86_64-little_endian-lp64" "Qt shader cache"

# ─── 5. npm cache ─────────────────────────────────────────────────────────────

if [[ -d "$HOME/.npm" ]]; then
    log "Cleaning npm cache..."
    npm_size=$(dir_size_bytes "$HOME/.npm")
    if $DRY_RUN; then
        log "npm cache: $(bytes_to_human "$npm_size") reclaimable"
        skip
    else
        npm cache clean --force 2>/dev/null || rm -rf "$HOME/.npm/_cacache"
        freed_total=$((freed_total + npm_size))
        ok "npm cache: freed $(bytes_to_human "$npm_size")"
    fi
fi

# ─── 6. Cargo registry cache ──────────────────────────────────────────────────

if [[ -d "$HOME/.cargo/registry/cache" ]]; then
    log "Cleaning cargo registry cache..."
    cargo_size=$(dir_size_bytes "$HOME/.cargo/registry/cache")
    if $DRY_RUN; then
        log "Cargo cache: $(bytes_to_human "$cargo_size") reclaimable"
        skip
    else
        rm -rf "$HOME/.cargo/registry/cache"
        rm -rf "$HOME/.cargo/registry/src"
        freed_total=$((freed_total + cargo_size))
        ok "Cargo registry cache: freed $(bytes_to_human "$cargo_size")"
    fi
fi

# ─── 7. Trash ──────────────────────────────────────────────────────────────────

echo ""
clean_dir "$HOME/.local/share/Trash" "Trash"

# ─── 8. Temp directories ──────────────────────────────────────────────────────

log "Cleaning temp directories..."
if $DRY_RUN; then
    tmp_size=$(dir_size_bytes /tmp)
    var_tmp_size=$(dir_size_bytes /var/tmp)
    log "/tmp: $(bytes_to_human "$tmp_size"), /var/tmp: $(bytes_to_human "$var_tmp_size")"
    skip
else
    # Only remove files older than 1 day in /tmp to avoid breaking running processes
    find /tmp -mindepth 1 -maxdepth 1 -mtime +0 -exec rm -rf {} + 2>/dev/null || true
    sudo find /var/tmp -mindepth 1 -mtime +1 -exec rm -rf {} + 2>/dev/null || true
    ok "Temp directories cleaned (files older than 1 day)"
fi

# ─── 9. Journal logs ──────────────────────────────────────────────────────────

log "Vacuuming systemd journal (keeping 1 week)..."
if $DRY_RUN; then
    journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+\S+' | head -1)
    log "Journal currently uses $journal_size"
    skip
else
    sudo journalctl --vacuum-time=7d --vacuum-size=200M 2>&1 | tail -2
    ok "Journal vacuumed"
fi

# ─── 10. Podman / Docker unused data ──────────────────────────────────────────

if command -v podman &>/dev/null; then
    log "Pruning unused podman data..."
    if $DRY_RUN; then
        skip
    else
        podman system prune -af --volumes 2>/dev/null || true
        ok "Podman pruned"
    fi
fi

if command -v docker &>/dev/null; then
    log "Pruning unused docker data..."
    if $DRY_RUN; then
        skip
    else
        docker system prune -af --volumes 2>/dev/null || true
        ok "Docker pruned"
    fi
fi

# ─── 11. Stale result symlinks ────────────────────────────────────────────────

log "Removing stale nix result symlinks..."
if $DRY_RUN; then
    find "$HOME" -maxdepth 3 -name "result" -type l 2>/dev/null | head -5
    skip
else
    find "$HOME" -maxdepth 3 -name "result" -type l -delete 2>/dev/null || true
    ok "Stale result symlinks removed"
fi

# ─── 12. recently-used.xbel ───────────────────────────────────────────────────

if [[ -f "$HOME/.local/share/recently-used.xbel" ]]; then
    log "Clearing recently-used.xbel..."
    if $DRY_RUN; then
        skip
    else
        : >"$HOME/.local/share/recently-used.xbel"
        ok "recently-used.xbel cleared"
    fi
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}══════════════════════════════════════${NC}"
if $DRY_RUN; then
    echo -e "${YELLOW}Dry run complete — no changes made.${NC}"
    echo -e "Run without ${BOLD}--dry-run${NC} to clean up."
else
    echo -e "${GREEN}Cleanup complete!${NC}"
    echo -e "Freed approximately ${BOLD}$(bytes_to_human $freed_total)${NC} (user-space tracked)"
    echo -e "Nix store + journal savings are additional."
fi
echo ""
df -h / | tail -1 | awk '{printf "Disk: %s used of %s (%s free, %s)\n", $3, $2, $4, $5}'
echo ""
