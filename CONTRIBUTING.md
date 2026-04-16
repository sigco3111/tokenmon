# Contributing

Thanks for looking at Tokenmon.

This repository is the public, source-available mirror of shipped Tokenmon
snapshots. We keep it buildable and inspectable, but we do not use it as the
primary day-to-day development repo.

## What To Expect

- GitHub Releases, Sparkle app updates, and Homebrew installs are published
  from this repository.
- Public source snapshots may lag behind private day-to-day development.
- If issue tracking is enabled, prefer focused bug reports and reproducible
  release regressions.
- Do not assume pull requests will be reviewed or merged on the same cadence as
  the release builds.

## Build And Verify

```bash
swift build
./scripts/ai-verify --mode pr
./scripts/build-release
```

## Public Repo Rules

- Keep the repo buildable from source.
- Do not add maintainer-only workflow assets, internal review artifacts, or
  private operator docs here.
- Keep user-facing docs product-first and release-focused.
- If a public snapshot changes release behavior, update the relevant release
  scripts and public docs in the same change.

## License

Tokenmon is source-available under `FSL-1.1-ALv2`. See [LICENSE.md](LICENSE.md),
[LICENSE-assets.md](LICENSE-assets.md), and [TRADEMARKS.md](TRADEMARKS.md).
