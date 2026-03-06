# Release Guide

This document describes how to publish this repository.

## 1. Pre-Release Checks
1. Confirm `09-RELEASE-CHECKLIST.md` is complete.
2. Confirm `08-PUBLISH-SECURITY-CHECKLIST.md` is complete.
3. Regenerate indexes and verify expected diffs.
4. Update `CHANGELOG.md`.

## 2. First Public Publish (Repository Bootstrap)
```bash
git init
git checkout -b main
git add .
git commit -m "chore: bootstrap boi-skills-tikhub-api governance baseline"
git remote add origin https://github.com/burst-of-inspiration/boi-skills-tikhub-api.git
git push -u origin main
```

## 3. Tag Alpha Release
```bash
git tag v0.1.0-alpha.5
git push origin v0.1.0-alpha.5
```

## 4. Stable Release (after runtime implementation)
```bash
git tag v0.1.0
git push origin v0.1.0
```

## 5. Post-Release
1. Verify GitHub Release notes are correct.
2. Link release in project README if needed.
3. Track follow-up issues from contributor feedback.
