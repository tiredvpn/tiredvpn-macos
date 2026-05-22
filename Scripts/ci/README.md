# CI Release Scripts

Helpers invoked by `.github/workflows/release.yml`. Each script is `set -euo
pipefail` and shellcheck-clean.

## Scripts

- `import-cert.sh` — decodes `CERT_P12_BASE64`, imports into a temp keychain at
  `$RUNNER_TEMP/build.keychain`, exports `BUILD_KEYCHAIN` to `$GITHUB_ENV`.
- `notarize.sh <app-or-dmg>` — wraps a `.app` in a zip, submits via
  `notarytool --wait`, dumps the notary log on failure, staples the ticket on
  success.
- `build-dmg.sh <app> <dmg>` — drag-to-Applications DMG via `create-dmg`, with
  an `hdiutil` fallback.

## Required secrets

| Secret | What it is | How to obtain |
| --- | --- | --- |
| `APPLE_ID` | Apple ID email used for notary submissions | The dev account email. |
| `APP_PASSWORD` | App-specific password for `APPLE_ID` | <https://appleid.apple.com> → Sign-In and Security → App-Specific Passwords → generate one labelled `tiredvpn-notarytool`. |
| `TEAM_ID` | 10-char Developer Team ID | <https://developer.apple.com/account> → Membership. |
| `CERT_P12_BASE64` | Developer ID Application certificate (private key + cert) | In Keychain Access → My Certificates → right-click the `Developer ID Application: …` entry → Export → `.p12` with a strong password. Then: `base64 -i cert.p12 \| pbcopy`. |
| `CERT_PASSWORD` | Password used when exporting the .p12 | Same password as above. |

`GITHUB_TOKEN` is provided automatically — no action needed.

## Local dry-run

The scripts assume `$RUNNER_TEMP` and `$GITHUB_ENV` exist (set by GitHub
Actions). To dry-run locally:

```sh
export RUNNER_TEMP="$(mktemp -d)"
export GITHUB_ENV="$RUNNER_TEMP/github_env"
touch "$GITHUB_ENV"
export CERT_P12_BASE64="$(base64 -i /path/to/cert.p12)"
export CERT_PASSWORD="…"
./Scripts/ci/import-cert.sh
```

Do **not** commit a real certificate or its password. Test notarization
against a throwaway build first — Apple rate-limits aggressive resubmits.

## Verifying a built DMG

```sh
spctl -a -t open --context context:primary-signature -vvv build/TiredVPN.dmg
xcrun stapler validate build/TiredVPN.dmg
```
