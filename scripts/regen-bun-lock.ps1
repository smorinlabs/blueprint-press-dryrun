# Regenerate bun.lock FROM SCRATCH for the declared [[regenerate]] rule.
$ErrorActionPreference = "Stop"
if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Error "regen-bun-lock: bun not found"
    exit 127
}
Remove-Item -Force -ErrorAction SilentlyContinue bun.lock
bun install
exit $LASTEXITCODE
