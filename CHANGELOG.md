# Changelog

## [0.7.0](https://github.com/mlorentedev/ci-workflows/compare/v0.6.0...v0.7.0) (2026-11-12)


### Features

* **docker-build:** add a composite that builds with a per-image gha layer cache ([#102](https://github.com/mlorentedev/ci-workflows/issues/102)) ([4591d9e](https://github.com/mlorentedev/ci-workflows/commit/4591d9ec08f777d37f87737266688f7822a7f37c))


### Bug Fixes

* **docker-publish:** pin the composite at its merge commit on main ([#109](https://github.com/mlorentedev/ci-workflows/issues/109)) ([36cc2f7](https://github.com/mlorentedev/ci-workflows/commit/36cc2f7be9298813a55e8da68873066f0746862e))
* **pr-agent:** bound the NaN prompt and fit its chain in the step ([#100](https://github.com/mlorentedev/ci-workflows/issues/100)) ([4dffe65](https://github.com/mlorentedev/ci-workflows/commit/4dffe6581a30c65cd8614771e2e7f7d891f3c374))
* **pr-agent:** publish review findings inline on every PR-Agent step ([#97](https://github.com/mlorentedev/ci-workflows/issues/97)) ([4934502](https://github.com/mlorentedev/ci-workflows/commit/49345029c38c0bffcdf6bd5c8f8dd10ff6144921))
* **pr-agent:** share the comment group only for a /review command ([#96](https://github.com/mlorentedev/ci-workflows/issues/96)) ([b0a2958](https://github.com/mlorentedev/ci-workflows/commit/b0a295891d743a78151083af44f9a58ec19cdc01))
* **pr-agent:** skip the publish guard in a run a push cancelled ([#94](https://github.com/mlorentedev/ci-workflows/issues/94)) ([e598a1d](https://github.com/mlorentedev/ci-workflows/commit/e598a1d6679fb860e3afc80b0c77dd358295ba82))

## [0.6.0](https://github.com/mlorentedev/ci-workflows/compare/v0.5.0...v0.6.0) (2026-11-12)


### Features

* **ci:** smoke the toolchain composites on macOS ([#79](https://github.com/mlorentedev/ci-workflows/issues/79)) ([c99cf9a](https://github.com/mlorentedev/ci-workflows/commit/c99cf9acbc2e92efaa5deb157e9604d41b1792f1))


### Bug Fixes

* **renovate:** group action updates apart, refresh uv locks, wait three days on new releases ([#80](https://github.com/mlorentedev/ci-workflows/issues/80)) ([4a9a883](https://github.com/mlorentedev/ci-workflows/commit/4a9a88320c3f34da8df3803e30ac60b5d7256360))
* **review:** keep comments and bot pushes from cancelling a PR-Agent review ([#78](https://github.com/mlorentedev/ci-workflows/issues/78)) ([0b4742d](https://github.com/mlorentedev/ci-workflows/commit/0b4742db0fa5bfa09083edbd7cced195d92c2e2c))
* **setup-node, setup-python-uv:** cache Playwright at one path on every OS and read CRLF version files ([#69](https://github.com/mlorentedev/ci-workflows/issues/69)) ([57b3b59](https://github.com/mlorentedev/ci-workflows/commit/57b3b5930e760f99e8ac6abdb606d1b00ea8179f))

## [0.5.0](https://github.com/mlorentedev/ci-workflows/compare/v0.4.0...v0.5.0) (2026-11-11)


### Features

* **hygiene:** add a composite that runs dotf's lessons check on any forge ([#54](https://github.com/mlorentedev/ci-workflows/issues/54)) ([0807897](https://github.com/mlorentedev/ci-workflows/commit/08078978c4816ff0b1f0edf5bc8b32a5f9df48e1))
* **setup-go-lint:** add a Go composite with its caches keyed on go.sum ([#64](https://github.com/mlorentedev/ci-workflows/issues/64)) ([e64d2c6](https://github.com/mlorentedev/ci-workflows/commit/e64d2c6a95a7165e021825ebf6da716958192da5))
* **setup-python-poetry:** add a cached Python and Poetry composite ([#55](https://github.com/mlorentedev/ci-workflows/issues/55)) ([299a48a](https://github.com/mlorentedev/ci-workflows/commit/299a48a5103bcaeb7bfa2972d414de9546347b0f))
* **setup-python-uv:** add a uv composite with its cache keyed on uv.lock ([#58](https://github.com/mlorentedev/ci-workflows/issues/58)) ([6727a5b](https://github.com/mlorentedev/ci-workflows/commit/6727a5b76bd9b6ade16f416a1af247a52d8e150e))


### Bug Fixes

* **renovate:** fail the run when a repository aborts on an error ([#62](https://github.com/mlorentedev/ci-workflows/issues/62)) ([1a2d938](https://github.com/mlorentedev/ci-workflows/commit/1a2d9387d13b3f71db0c5c028486a55bc6050b80))
* **renovate:** open updates all Monday so a delayed cron still lands in the window ([#49](https://github.com/mlorentedev/ci-workflows/issues/49)) ([91bf940](https://github.com/mlorentedev/ci-workflows/commit/91bf940674227ed26037f0f8b023bb15ccbdface))

## [0.4.0](https://github.com/mlorentedev/ci-workflows/compare/v0.3.0...v0.4.0) (2026-11-06)


### Features

* **pages:** add a reusable GitHub Pages workflow ([#41](https://github.com/mlorentedev/ci-workflows/issues/41)) ([0264c74](https://github.com/mlorentedev/ci-workflows/commit/0264c74a961afa49b2a3aecfc7caddbfbd0a8005))
* **renovate:** one preset and one run for every repository ([#35](https://github.com/mlorentedev/ci-workflows/issues/35)) ([20ebfdb](https://github.com/mlorentedev/ci-workflows/commit/20ebfdb562ac534958a1978c438e41d652a3a28f))
* **setup-node:** add a cached Node toolchain composite ([#42](https://github.com/mlorentedev/ci-workflows/issues/42)) ([a249f67](https://github.com/mlorentedev/ci-workflows/commit/a249f67957c9110bdf07f48c1ec21bad186a0f33))


### Bug Fixes

* **release:** cut a release only for feat, fix, perf and revert ([#25](https://github.com/mlorentedev/ci-workflows/issues/25)) ([133d3c0](https://github.com/mlorentedev/ci-workflows/commit/133d3c0b7364a9c1fe1be44783a65c84cbce5dd0))

## 0.3.0 (2026-11-05)

## What's Changed
* feat(release): release with release-please through a shared release workflow by @mlorentedev in https://github.com/mlorentedev/ci-workflows/pull/19


**Full Changelog**: https://github.com/mlorentedev/ci-workflows/compare/v0.2.0...v0.3.0
