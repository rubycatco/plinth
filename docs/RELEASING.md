# Releasing

Plinth ships as a disk image signed with a Developer ID certificate and notarized by Apple, so it opens on any Mac without Gatekeeper warnings.

## Cut a release

Tag the commit on `main` and push the tag:

```sh
git tag v1.2.0
git push origin v1.2.0
```

What happens next depends on whether the repository has the signing secrets listed under [One-time setup](#one-time-setup). `gh secret list` shows them.

- **With the secrets**, the [Release workflow](../.github/workflows/release.yml) builds `Plinth-1.2.0.dmg` (the tag sets the version), signs and notarizes it, staples the ticket, and publishes it as a GitHub release with generated notes.
- **Without them**, the workflow builds an ad hoc signed image, keeps it in the run's artifacts, and publishes nothing. The run still succeeds, with a warning. Build the signed image on your Mac and publish it by hand, as below.

Running the workflow by hand from the Actions tab only builds the disk image and keeps it in the run's artifacts.

### Publishing by hand

With your certificate and notarization profile set up as in [Building a signed image locally](#building-a-signed-image-locally), build from the tagged commit:

```sh
git switch --detach v1.2.0
PLINTH_VERSION=1.2.0 \
PLINTH_BUILD=$(git rev-list --count HEAD) \
PLINTH_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
PLINTH_NOTARY_PROFILE=plinth-notary \
./scripts/make_dmg.sh
```

Set `PLINTH_VERSION` and `PLINTH_BUILD` as shown. Without them the app keeps the version in `App/Info.plist`, and the image is named after it. `PLINTH_BUILD` matches what the workflow uses: the number of commits up to the tag.

Check the image, then publish it with your notes and its SHA-256:

```sh
spctl -a -vv -t open --context context:primary-signature build/Plinth-1.2.0.dmg
shasum -a 256 build/Plinth-1.2.0.dmg
gh release create v1.2.0 build/Plinth-1.2.0.dmg --title "Plinth 1.2.0" --notes-file notes.md
```

Earlier releases have notes in English and Simplified Chinese, with install steps and the image's SHA-256. Use them as a template.

## One-time setup

This needs a paid Apple Developer Program membership.

1. **Developer ID certificate.** In Xcode, open Settings → Accounts, select the team, choose Manage Certificates, click +, and pick Developer ID Application. Only the team's Account Holder can create one.
2. **Export it for CI.** In Keychain Access, under My Certificates, right-click "Developer ID Application: …", choose Export, and save a `.p12` file with a password.
3. **Notarization key.** In App Store Connect, go to Users and Access → Integrations → App Store Connect API → Team Keys and generate a key with Developer access. Download the `.p8` file (it can only be downloaded once) and note its Key ID and the Issuer ID shown above the list.
4. **Repository secrets.** From the repository folder:

   ```sh
   base64 -i DeveloperID.p12 | gh secret set MACOS_CERTIFICATE_P12
   gh secret set MACOS_CERTIFICATE_PASSWORD          # paste the .p12 password
   gh secret set NOTARY_API_KEY_P8 < AuthKey_XXXXXXXXXX.p8
   gh secret set NOTARY_API_KEY_ID --body XXXXXXXXXX
   gh secret set NOTARY_API_ISSUER_ID --body 00000000-0000-0000-0000-000000000000
   ```

   Then delete the exported `.p12`.

## Building a signed image locally

Save the notarization key in your keychain once, then point the script at your certificate:

```sh
xcrun notarytool store-credentials plinth-notary \
  --key AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer 00000000-0000-0000-0000-000000000000

PLINTH_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
PLINTH_NOTARY_PROFILE=plinth-notary \
./scripts/make_dmg.sh
```

Without those variables, `./scripts/make_dmg.sh` makes an ad hoc signed image, which opens on your own Mac but not on others.
