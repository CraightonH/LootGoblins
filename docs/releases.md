# Automatic releases

LootGoblins uses the versioned workflows in [CraightonH/wow-addon-template](https://github.com/CraightonH/wow-addon-template/blob/main/docs/reusable-workflows.md). Its source layout, Lua tests and reproducible Python builder remain local to this repository. The shared workflows own package validation, release manifests, GitHub releases and CurseForge deployment.

## Configuration

`addon.json` targets CurseForge project **1806558**, Forever interface **16001**, source directory `LootGoblins/` and artifact directory `dist/`. The TOC declares the same project ID. The ZIP includes the MIT license.

The repository's `CF_API_TOKEN` secret is passed only to the deployment workflow. The job uses the `curseforge` environment; no environment approval is configured, so a valid tag can deploy automatically. No additional release-enable variable is needed in LootGoblins. Keep the author token in GitHub Secrets.

## Publish a release

First test the intended code in game, commit and push it, then create an unused annotated version tag. For example:

```sh
git switch main
git pull --ff-only
git tag -a v0.3.2-alpha.1 -m 'LootGoblins 0.3.2 alpha 1'
git push origin v0.3.2-alpha.1
```

Choose the actual next version you want to publish. This example is not a tag created by the setup work. Tags identify the source being released; they do not import newer code from another working copy.

The **Release and deploy** workflow runs both Lua versions and packaging tests, builds the archive, validates its layout and checksum, creates a GitHub release, then uploads that same ZIP to CurseForge. The pushed tag supplies the package version. The tracked TOC remains a development version, so a separate version-bump commit is unnecessary. The builder reads `ADDON_RELEASE_VERSION` during tagged builds and leaves the working tree intact.

`vX.Y.Z` selects a stable release. `vX.Y.Z-alpha`, `vX.Y.Z-alpha.N`, `vX.Y.Z-beta` and `vX.Y.Z-beta.N` select alpha/beta and mark the GitHub release as a prerelease. Use a new tag for changed code; never move or reuse a published release tag.

Successful CurseForge uploads attach `curseforge-upload.json` to the GitHub release. It records the file ID and archive identity and suppresses duplicate uploads on ordinary retries. GitHub Actions and that receipt are the deployment record. CurseForge approval or moderation is outside the workflow.

## Retry and recover

Use **Retry existing release deployment** on the default branch, entering the existing tag, or rerun failed jobs in the original release workflow. Recovery uploads the original GitHub asset without rebuilding it. Existing matching receipts cause a successful skip.

If an upload has an ambiguous network failure, or succeeded but saving its receipt failed, check CurseForge before rerunning. Recover the original file ID into a receipt as described in the shared workflow documentation. The API does not guarantee that repeating an upload is idempotent.

## Adopt shared updates

All three caller workflows reference `workflows-v1.0.1`. To adopt a new shared release, update both `uses: ...@VERSION` and `tooling-ref: VERSION` in each caller and verify branch CI. No shared scripts need to be copied into LootGoblins.
