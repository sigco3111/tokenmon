# Tokenmon Public Source Overview

**Document status:** Public source guide  
**Audience:** Evaluators, advanced users, and maintainers building from the public mirror  
**Related docs:** `../../README.md`, `../../CONTRIBUTING.md`, `../../LICENSE.md`, `../../TRADEMARKS.md`

---

## 1. Purpose

This repository is the public, source-available mirror of shipped Tokenmon
snapshots.

It exists to provide:

- inspectable product code
- a buildable local source snapshot
- GitHub Releases for DMG and ZIP downloads
- the Sparkle `appcast.xml` and Homebrew cask assets used by release builds

---

## 2. What is included here

The public mirror keeps:

- app source under `Sources/`
- automated checks, fixtures, and public tests
- packaging metadata and release scripts
- screenshots and runtime assets needed to build the app
- the minimum docs needed to explain the public source surface

---

## 3. What is intentionally omitted

The public mirror does not carry the full private maintainer workspace.

That means this repo intentionally omits:

- internal planning and execution docs
- maintainer-only workflow assets and AI agent configs
- private review boards and art review artifacts
- internal repair scripts and operator runbooks

If you do not see a maintainer workflow document here, assume it belongs to the
private development repo rather than the public release mirror.

---

## 4. Build and verification

The public repo should remain buildable with the canonical public entrypoints:

```bash
swift build
./scripts/ai-verify --mode pr
./scripts/build-release
```

Use `./scripts/run-ai-verify` when you want the full local completion lane that
still applies to the public release surface.

---

## 5. Release ownership

This public repository is the canonical source for:

- GitHub release assets
- Sparkle update metadata
- Homebrew cask artifacts

Public release targeting is driven by `Packaging/Tokenmon-Info.plist` and the
helper script `scripts/tokenmon-release-targets`.

---

## 6. Contribution posture

This repo is intentionally closer to a release mirror than to a normal
open-collaboration development repo.

Practical implications:

- public snapshots are selected, not continuous
- issues and PRs may be accepted selectively or not at all
- source visibility does not imply open-source governance

See the license files for the exact legal terms.
