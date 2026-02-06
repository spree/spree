# Changesets

This folder is used by [Changesets](https://github.com/changesets/changesets) to track SDK version bumps and changelog entries.

## Adding a changeset

After making changes to the SDK, run:

```bash
cd sdk
npx changeset
```

This will prompt you to:
1. Select the package (`@spree/sdk`)
2. Choose the semver bump type (patch/minor/major)
3. Write a summary of the changes

A markdown file will be created in this directory describing the change.

## Releasing

When changeset files are merged to `main`, a "Version Packages" PR is automatically created. Merging that PR bumps the version, updates the CHANGELOG, and publishes to npm.
