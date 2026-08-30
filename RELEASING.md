# Releasing

Two version lines exist here and move independently. Do not conflate them:

- **Action version** - the git tags in this repo. Consumers pin `vulnlog/setup-vulnlog@v1`.
- **Vulnlog CLI version** - the `version` input. Cutting a Vulnlog CLI release needs no action release: the native
  assets are versionless, so the download URL is built from the tag at run time.

You only release this action when its own behaviour changes.

## Before tagging

- `main` is green, including the scheduled `contract` job.
- Locally: `shellcheck install.sh`, `actionlint`, `bats tests/`.
- The input and output tables in `README.md` match `action.yml`.
- Everything is still ASCII:
  `LC_ALL=C grep -rnP '[^\x09\x0A\x20-\x7E]' --include='*.sh' --include='*.yml' --include='*.bats' --include='*.md' .`

## Pick the number

Semver applies to the action's interface, not to the CLI it installs.

- **Major** - an input or output is removed or renamed, a default changes, or a runner that used to work no longer does.
  Breaks consumers pinned to `v1`.
- **Minor** - a new input with a default, a new output, a newly supported runner, or a new native platform added to
  `platform_slug`.
- **Patch** - fixes with no interface change.

## Cut it

```sh
git switch main && git pull
git tag -a v1.2.0 -m "v1.2.0"
git push origin v1.2.0
gh release create v1.2.0 --title v1.2.0 --generate-notes
```

## Move the floating major tag

This is the tag consumers actually use. It is force-moved on every release that stays inside the same major line, and it
is the step that is easy to forget.

```sh
git tag -f v1 v1.2.0
git push -f origin v1
```

- Cut a new major line (`v2`) only for a breaking change, and leave `v1`
  pointing at the last compatible release so existing workflows keep working.
- Never move a `vX.Y.Z` tag. Only the bare `vX` tag floats.

## First release only

- Make the repository public.
- On the release page, tick **Publish this Action to the GitHub Marketplace**
  and accept the developer agreement.
- The listing requires `action.yml` at the repo root with a `name` that is unique across the Marketplace, and a
  `branding` block. Both are in place.
- Set the repository **Social preview** image under Settings > General.

## After

- Confirm the listing renders: <https://github.com/marketplace/actions/setup-vulnlog-cli>.
- Smoke-test the floating tag from another repository:

```yaml
- uses: vulnlog/setup-vulnlog@v1
- run: vulnlog --version
```

- If a release is broken, move `v1` back to the previous good tag first, then fix forward. Deleting the bad `vX.Y.Z` tag
  does not help anyone already pinned to it.
