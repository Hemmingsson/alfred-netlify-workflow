# Releasing

Publish `Netlify.alfredworkflow` on a versioned [GitHub release](https://github.com/Hemmingsson/alfred-netlify-workflow/releases). Keep this asset name so the README download link works.

## Setup

You need:

- Swift 6 and the macOS SDK from Xcode or Command Line Tools.
- A **Developer ID Application** identity in Keychain. Development and Distribution certificates cannot replace it.
- A Keychain notarisation profile. This guide uses `netlify-notary`.
- GitHub CLI authenticated with access to this repository.

Check signing identities:

```sh
security find-identity -v -p codesigning
```

Create the notarisation profile and follow the prompts:

```sh
xcrun notarytool store-credentials netlify-notary
```

Use an Apple app-specific password or App Store Connect API key. Keep credentials out of the repository.

## Publish

1. Set `version` in `workflow/info.plist`, for example `1.0.0`. Update the docs. Run `swift test`. Commit the changes.
2. Build, sign and notarise:

   ```sh
   NOTARY_PROFILE=netlify-notary scripts/build.sh
   ```

   The script builds for arm64 and x86_64. It signs with Developer ID and the hardened runtime, submits to Apple, then checks with `codesign` and Gatekeeper.

   Publish only if notarisation reports **Accepted** and Gatekeeper reports **Notarized Developer ID**. `SIGN_IDENTITY` selects a specific identity. Without a profile, the script skips notarisation. Without an identity, it uses ad-hoc signing.
3. Check the package version, executable permissions and archive contents. Install and test the exact package. Launch External Trigger `browse` for UI checks. Do not rebuild with different signing settings after these checks.
4. Push, tag and publish. Replace the version and notes path below:

   ```sh
   git push origin main
   git tag v1.0.0
   git push origin v1.0.0
   gh release create v1.0.0 dist/Netlify.alfredworkflow \
     --verify-tag --title "1.0" --notes-file /path/to/release-notes.md --latest
   ```

5. Download the published asset. Compare it with the checked local package.

Release notes must describe changes, link the workflow download and state requirements.

The archive root must contain `info.plist`, icons, the `.alfredui` bundle and the executable. Exclude build products, local preferences and account data.

A standalone binary cannot carry a stapled notarisation ticket. Gatekeeper retrieves the ticket online on first use. This binary needs no extra entitlements.

The Alfred Gallery needs a separate submission. See the [sharing guide](https://www.alfredapp.com/help/workflows/advanced/sharing-workflows/).

## Development

```sh
scripts/build.sh --debug --install
```

This builds for the current Mac and installs into Alfred. It keeps workflow settings and skips notarisation. It uses an Apple Development identity when available, otherwise ad-hoc signing.

| Variable | Override |
|---|---|
| `ALFRED_WORKFLOWS_DIR` | Install destination |
| `PACKAGE_DIR` | Swift package path |

## Screenshots and diagrams

`scripts/screenshot.sh` builds offline demo data and captures `assets/screenshot.png`. A temporary wallpaper window preserves Alfred’s blur. Set `SCREENSHOT_WALLPAPER` to use another image. The script removes its temporary `netlify_demo` setting on exit.

Diagram sources live in `demo/diagrams/`. Exports live in `assets/diagrams/`. After editing wireframes or exporting technical diagrams, run:

```sh
python3 demo/diagrams/build-wireframes.py
python3 demo/diagrams/style-diagrams.py
```

The PNG renderer needs `resvg`. Both scripts work from any directory.
