# Changelog

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
