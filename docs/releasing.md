# Release policy

Graphomaton follows semantic versioning. Patch releases contain compatible fixes,
minor releases contain compatible features and announced deprecations, and major
releases may remove deprecated behavior. Security fixes target the latest release
as described in `SECURITY.md`.

To release:

1. Move completed entries from Unreleased to a dated version section.
2. Set `Graphomaton::VERSION` to the same version and run `bundle exec rake`.
3. Build and locally install the gem and smoke-test `graphomaton --version`.
4. Push the signed or annotated `vVERSION` tag.

The tag workflow verifies the tag/version match, reruns tests and RBS validation,
builds and installs the package, then uses RubyGems trusted publishing with a
short-lived OIDC token. The RubyGems publisher must be configured for
`.github/workflows/release.yml` and the protected `release` environment. No
long-lived RubyGems API key is stored in the repository.
