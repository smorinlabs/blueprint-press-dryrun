#!/usr/bin/env bash
# init/guard.sh — blueprint setup guard, two modes:
#   guard.sh warn   → Tier 1: one-line stderr banner, always exit 0
#   guard.sh block  → Tier 2: full message + exit 1
#
# Shared skip conditions (any one of them silences both modes):
#   1. init/.blueprint-initialized exists  → migration already done
#   2. press/press-receipt.toml exists     → rebranded by template-press
#   3. init/.blueprint-contributor exists  → local opt-out for blueprint maintainers
#   4. origin URL (normalized) matches the canonical blueprint repo
#
# Condition 2 exists because the rebrand engine is migrating out of this repo:
# `press rebrand` writes a receipt where init.py writes the marker, and a fork
# pressed with the external tool must not be blocked forever by a guard that
# only recognizes the embedded engine's artifact. Both are accepted — this is
# additive, so forks carrying only the legacy marker keep working untouched.
#
# POSIX-y bash; no Python, no venv. Hot path: runs before `uv sync` on a bare clone.

set -u

guard_dir="$(cd "$(dirname "$0")" && pwd)"
marker="${guard_dir}/.blueprint-initialized"
receipt="${guard_dir}/../press/press-receipt.toml"
contributor="${guard_dir}/.blueprint-contributor"

# Canonical blueprint owner/repo pairs. Pre-org-move (`smorin/`) included so
# people who cloned before the move still get a silent guard.
blueprint_owner_repos="smorinlabs/blueprint-press-dryrun smorin/blueprint-press-dryrun"

parse_origin() {
    # Echoes "owner/repo" with trailing .git stripped; empty if no origin or unparsable.
    url="$(git -C "${guard_dir}/.." remote get-url origin 2>/dev/null)" || return 0
    [ -n "$url" ] || return 0
    printf '%s' "$url" \
        | sed -E 's#^(https?://github\.com/|git@github\.com:)([^/]+)/([^/]+)$#\2/\3#' \
        | sed -E 's#\.git$##'
}

origin_matches_blueprint() {
    parsed="$(parse_origin)"
    [ -n "$parsed" ] || return 1
    for blue in $blueprint_owner_repos; do
        [ "$parsed" = "$blue" ] && return 0
    done
    return 1
}

should_skip() {
    [ -f "$marker" ] && return 0
    [ -f "$receipt" ] && return 0
    [ -f "$contributor" ] && return 0
    origin_matches_blueprint && return 0
    return 1
}

mode="${1:-warn}"

case "$mode" in
    warn)
        if ! should_skip; then
            # One-line banner. ALWAYS exit 0 — a non-zero exit from a `just`
            # `shell()` call aborts the recipe, which would weaponize Tier 1
            # into Tier 2.
            printf >&2 '\033[33m⚠  blueprint un-initialized — run `just init` to re-brand this project (or `just init-doctor` to diagnose).\033[0m\n'
        fi
        exit 0
        ;;
    block)
        if should_skip; then
            exit 0
        fi
        cat >&2 <<'EOF'

  ───────────────────────────────────────────────────────────────────────
  ⛔  This recipe is blocked until the project is initialized.

  You are running a recipe that produces a wrong artifact, an external
  side effect, or an identity-bearing write — but this project still
  carries the blueprint-press-dryrun identity (package name, repo name,
  CLI command, copyright holder, URLs).

  Run one of:
      just init          → interactive re-brand walkthrough
      just init-doctor   → diagnose what's missing

  Escape hatches:
      • If you forked the blueprint to contribute back, create
        init/.blueprint-contributor (git-ignored) to silence this guard.
      • If your origin is set to the blueprint repo, the guard already
        skips automatically.
  ───────────────────────────────────────────────────────────────────────

EOF
        exit 1
        ;;
    *)
        printf >&2 'guard.sh: unknown mode %s (expected: warn | block)\n' "$mode"
        exit 2
        ;;
esac
