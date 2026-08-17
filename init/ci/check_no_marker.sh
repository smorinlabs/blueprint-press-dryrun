#!/usr/bin/env bash
# CI check: the blueprint marker must NOT exist in the upstream repo.
#
# This guards a category of foot-gun: someone runs `just init` on the blueprint
# itself and commits the resulting marker (and rewritten files), which would
# corrupt the template. The check is SCOPED — it only fires when the repo
# being checked is itself named `py-launch-blueprint` (in $GITHUB_REPOSITORY).
# That way the same workflow can ship downstream without firing falsely.
#
# Layered defense: `init --prune` also deletes the workflow file itself.
#
# The press receipt (press/press-receipt.toml) is the same foot-gun via the
# external engine: guard.sh accepts it as an initialized marker, so a receipt
# committed to the blueprint would silently disarm both guard tiers in every
# generated project. It is rejected here alongside the legacy marker.
#
# Exit 0  → all good (marker and receipt absent, or repo is not the blueprint)
# Exit 1  → marker or receipt present in the blueprint repo

set -eu

scope="${GITHUB_REPOSITORY:-}"
marker_path="${MARKER_PATH:-init/.blueprint-initialized}"
receipt_path="${RECEIPT_PATH:-press/press-receipt.toml}"

# Outside the blueprint repo this check is a no-op.
case "$scope" in
    */py-launch-blueprint) ;;
    "")
        # Local invocation with no GITHUB_REPOSITORY — fall back to enforcing.
        ;;
    *)
        printf 'check_no_marker: repo %s is not the blueprint — skipping.\n' "$scope"
        exit 0
        ;;
esac

if [ -f "$marker_path" ]; then
    printf >&2 'check_no_marker: %s exists in the blueprint repo — '\
'someone has run `just init` here and committed the result. Revert.\n' "$marker_path"
    exit 1
fi

if [ -f "$receipt_path" ]; then
    printf >&2 'check_no_marker: %s exists in the blueprint repo — '\
'someone has run `press rebrand` here and committed the receipt. Revert.\n' "$receipt_path"
    exit 1
fi

printf 'check_no_marker: %s and %s absent — ok\n' "$marker_path" "$receipt_path"
exit 0
