# Release Skill

Automate the release process with validation checks.

## Procedure

### 1. Pre-release Checks
- Verify working tree is clean: `git status`
- Verify all tests pass: `bash tests/run-all.sh`
- Check for uncommitted changes

### 2. Determine Version
- Review changes since last tag: `git log $(git describe --tags --abbrev=0)..HEAD --oneline`
- Apply semver rules:
  - MAJOR: Breaking API changes
  - MINOR: New features, backward compatible
  - PATCH: Bug fixes only

### 3. Update Changelog
- Group changes by type (Added, Changed, Fixed, Removed)
- Include commit references
- Add date and version header

### 4. Create Release
- Update version in `.claude-plugin/plugin.json`
- Create git tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
- Generate release notes

### 5. Summary
- Display version bump
- List key changes
- Show next steps (push tag, deploy, etc.)
