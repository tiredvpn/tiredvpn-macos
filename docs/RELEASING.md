# Releasing TiredVPN for macOS

End-to-end runbook for cutting a notarized DMG release.

## Prerequisites

- Active **Apple Developer Program** enrollment (individual or organization).
- **Developer ID Application** certificate generated at
  <https://developer.apple.com/account/resources/certificates> and exported to
  `.p12` (Keychain Access → My Certificates → Export).
- All required secrets configured in GitHub repo settings — see
  [`Scripts/ci/README.md`](../Scripts/ci/README.md).
- A published release of `tazhate/tiredvpn-oss` containing
  `libtiredvpn.a`, `libtiredvpn.h`, and matching `.sha256` files.

## Release procedure

1. **Pin the Go core version.**

   ```sh
   echo "v1.x.y" > Vendor/VERSION
   ./Scripts/fetch-core.sh   # smoke-test locally if on macOS
   ```

2. **Bump app version.** Edit `project.yml`:
   - `MARKETING_VERSION` — user-visible (`1.2.0`).
   - `CURRENT_PROJECT_VERSION` — monotonic build number (`42`).

3. **Commit and open a PR.** Land on `main`.

4. **Tag.**

   ```sh
   git tag v1.2.0
   git push origin v1.2.0
   ```

5. **Watch the workflow** at Actions → `release`. Expected runtime ~20-30 min
   on `macos-14`; notarization wait dominates.

6. **Verify the published release.** Download the DMG, open it on a clean
   macOS box, drag into Applications, launch. Gatekeeper should accept it
   without warnings.

## Manual dry-run (no upload)

Use the **workflow_dispatch** trigger from the Actions tab. The
`libtiredvpn_version` input lets you point at a prerelease core build. The DMG
is built and notarized but **not** uploaded to a GitHub release.

## Common failures

### Notary rejected: "The signature does not include a secure timestamp"

Codesign step didn't pass `--timestamp`. Xcode normally adds it for
`Developer ID Application` — verify `CODE_SIGN_IDENTITY` is exactly
`Developer ID Application` (not "Apple Development").

### Notary rejected: "The executable does not have the hardened runtime enabled"

Set `ENABLE_HARDENED_RUNTIME = YES` in `project.yml` (must apply to both the
app and the extension target).

### "errSecInternalComponent" during codesign

Keychain partition list wasn't set. Re-check that `import-cert.sh` ran and
that `security set-key-partition-list` succeeded. Usually a stale runner —
re-run the job.

### "Invalid Entitlement: com.apple.developer.networking.networkextension"

The Developer ID provisioning profile attached to the extension doesn't
include the Network Extension entitlement. Re-issue the profile with the
`packet-tunnel-provider` capability on developer.apple.com.

### "The contents of the package are invalid" (DMG notarization)

`create-dmg` produced an unsigned DMG. The DMG itself doesn't need a signature
but every Mach-O inside must be signed. Make sure the `.app` is signed and
notarized **before** DMG creation.

### Notary timeout / "In Progress" for >30 min

Apple's notary queue is occasionally slow. Re-running the job is safe — the
submission is idempotent on the artifact's hash.

## Hotfix

For a hotfix without a Go core bump, leave `Vendor/VERSION` untouched, bump
only `CURRENT_PROJECT_VERSION` in `project.yml`, tag `v1.2.1`, push.

## Rolling back

GitHub releases can be deleted from the UI. Users who already downloaded the
bad build will need a manual update — there is no auto-update mechanism yet
(Sparkle integration is post-MVP).
