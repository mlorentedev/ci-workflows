#!/usr/bin/env bats
#
# The setup-python-poetry composite (spec CI-004, issue #10). actions/setup-python
# and actions/cache are not run here: the tests read their wiring from
# action.yml, and run the composite's own scripts the way a composite runs them.

ACTION="${BATS_TEST_DIRNAME}/../.github/actions/setup-python-poetry/action.yml"
WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/lint.yml"
FIXTURE="${BATS_TEST_DIRNAME}/fixtures/toolchains/poetry"

step() { yq ".runs.steps[] | select(.id == \"$1\") | .$2" "${ACTION}"; }

setup() {
  export GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/output" GITHUB_PATH="${BATS_TEST_TMPDIR}/path" GITHUB_ENV="${BATS_TEST_TMPDIR}/env"
  : >"${GITHUB_OUTPUT}"
  : >"${GITHUB_PATH}"
  : >"${GITHUB_ENV}"
  for id in resolve keys install-poetry; do
    step "${id}" run >"${BATS_TEST_TMPDIR}/${id}.sh"
  done
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "${WORK}"
}

run_step() { run bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/$1.sh"; }

output_of() { sed -n "s/^$1=//p" "${GITHUB_OUTPUT}" | tail -1; }

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

# A python that records its calls, and whose `-m venv DIR` makes a venv whose
# pip "installs" Poetry by writing DIR/bin/poetry.
stub_python() {
  local bin="${BATS_TEST_TMPDIR}/stub"
  mkdir -p "${bin}"
  cat >"${bin}/python" <<'EOF'
#!/usr/bin/env bash
echo "python $*" >>"${STUB_LOG}"
if [ "$1 $2" = "-m venv" ]; then
  set -- "$1" "$2" "${@: -1}"
  rm -rf "$3"
  mkdir -p "$3/bin"
  cat >"$3/bin/python" <<'PY'
#!/usr/bin/env bash
echo "venv-python $*" >>"${STUB_LOG}"
d=$(cd "$(dirname "$0")" && pwd)
last="${*: -1}"
printf '#!/usr/bin/env bash\necho "Poetry (version %s)"\n' "${last##*==}" >"${d}/poetry"
chmod +x "${d}/poetry"
PY
  chmod +x "$3/bin/python"
fi
EOF
  chmod +x "${bin}/python"
  export STUB_LOG="${BATS_TEST_TMPDIR}/calls" PYTHON="${bin}/python"
  : >"${STUB_LOG}"
}

# Shape (AC1)

@test "the inputs and their defaults" {
  [ "$(yq '.inputs.version.default' "${ACTION}")" = "" ]
  [ "$(yq '.inputs.version-file.default' "${ACTION}")" = ".python-version" ]
  [ "$(yq '.inputs.poetry-version.default' "${ACTION}")" = "" ]
  [ "$(yq '.inputs.working-directory.default' "${ACTION}")" = "." ]
}

@test "the outputs map to the venv cache, the keys, the Poetry cache and setup-python" {
  [ "$(yq '.outputs.cache-hit.value' "${ACTION}")" = '${{ steps.venv.outputs.cache-hit }}' ]
  [ "$(yq '.outputs.cache-primary-key.value' "${ACTION}")" = '${{ steps.keys.outputs.venv-key }}' ]
  [ "$(yq '.outputs.poetry-cache-hit.value' "${ACTION}")" = '${{ steps.poetry-cache.outputs.cache-hit }}' ]
  [ "$(yq '.outputs.python-version.value' "${ACTION}")" = '${{ steps.setup.outputs.python-version }}' ]
}

@test "the scripts run under bash" {
  [ "$(step resolve shell)" = "bash" ]
  [ "$(step keys shell)" = "bash" ]
  [ "$(step install-poetry shell)" = "bash" ]
}

@test "every third-party action is pinned by full SHA with its tag as a comment" {
  local uses pinned
  uses=$(grep -cE '^\s+uses: [^.]' "${ACTION}")
  pinned=$(grep -cE '^\s+uses: [a-z0-9-]+/[a-z0-9-]+@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$' "${ACTION}")
  [ "${uses}" -ge 3 ]
  [ "${uses}" -eq "${pinned}" ]
}

@test "setup-python installs the resolved version with no cache of its own" {
  [ "$(step setup uses | cut -d@ -f1)" = "actions/setup-python" ]
  [ "$(step setup with.python-version)" = '${{ steps.resolve.outputs.version }}' ]
  [ "$(step setup with.python-version-file)" = '${{ steps.resolve.outputs.file }}' ]
  [ "$(step setup with.cache)" = "null" ]
}

@test "the caches store Poetry's venv and the project's in-project venv under the keys step's keys" {
  [ "$(step poetry-cache uses | cut -d@ -f1)" = "actions/cache" ]
  [ "$(step poetry-cache with.path)" = '${{ steps.keys.outputs.poetry-dir }}' ]
  [ "$(step poetry-cache with.key)" = '${{ steps.keys.outputs.poetry-key }}' ]
  [ "$(step venv uses | cut -d@ -f1)" = "actions/cache" ]
  [ "$(step venv with.path)" = '${{ inputs.working-directory }}/.venv' ]
  [ "$(step venv with.key)" = '${{ steps.keys.outputs.venv-key }}' ]
}

@test "Poetry is installed with setup-python's interpreter, after its cache" {
  [ "$(step install-poetry env.PYTHON)" = '${{ steps.setup.outputs.python-path }}' ]
  [ "$(step install-poetry env.POETRY_DIR)" = '${{ steps.keys.outputs.poetry-dir }}' ]
  [ "$(yq '.runs.steps[].id' "${ACTION}" | tr '\n' ' ')" = "resolve setup keys poetry-cache install-poetry venv " ]
}

# Version source (AC2)

@test "a version input is installed as given" {
  touch "${WORK}/poetry.lock"
  VERSION=3.12.7 VERSION_FILE=.python-version POETRY_VERSION=2.5.1 WORKDIR="${WORK}" run_step resolve
  [ "$status" -eq 0 ]
  [ "$(output_of version)" = "3.12.7" ]
  [ "$(output_of file)" = "" ]
}

@test "the version input wins over a present version file" {
  touch "${WORK}/poetry.lock"
  echo 3.12 >"${WORK}/.python-version"
  VERSION=3.13 VERSION_FILE=.python-version POETRY_VERSION=2.5.1 WORKDIR="${WORK}" run_step resolve
  [ "$(output_of version)" = "3.13" ]
  [ "$(output_of file)" = "" ]
}

@test "without a version input, the version file in the working directory is used" {
  touch "${WORK}/poetry.lock"
  echo 3.13 >"${WORK}/.python-version"
  VERSION='' VERSION_FILE=.python-version POETRY_VERSION=2.5.1 WORKDIR="${WORK}" run_step resolve
  [ "$status" -eq 0 ]
  [ "$(output_of version)" = "" ]
  [ "$(output_of file)" = "${WORK}/.python-version" ]
}

@test "with neither a version nor the file, the step fails naming both" {
  touch "${WORK}/poetry.lock"
  VERSION='' VERSION_FILE=.python-version POETRY_VERSION=2.5.1 WORKDIR="${WORK}" run_step resolve
  [ "$status" -ne 0 ]
  [[ "$output" == *"version"* ]]
  [[ "$output" == *"${WORK}/.python-version"* ]]
}

@test "an empty Poetry version fails" {
  touch "${WORK}/poetry.lock"
  VERSION=3.13 VERSION_FILE=.python-version POETRY_VERSION='' WORKDIR="${WORK}" run_step resolve
  [ "$status" -ne 0 ]
  [[ "$output" == *"poetry-version"* ]]
}

@test "a Poetry version range fails rather than drift under a fixed key" {
  touch "${WORK}/poetry.lock"
  for v in '>=1.8,<2.0' latest 2 '2.5.*'; do
    VERSION=3.13 VERSION_FILE=.python-version POETRY_VERSION="${v}" WORKDIR="${WORK}" run_step resolve
    [ "$status" -ne 0 ]
    [[ "$output" == *"exact"* ]]
  done
}

@test "a missing poetry.lock fails naming its path" {
  VERSION=3.13 VERSION_FILE=.python-version POETRY_VERSION=2.5.1 WORKDIR="${WORK}" run_step resolve
  [ "$status" -ne 0 ]
  [[ "$output" == *"${WORK}/poetry.lock"* ]]
}

@test "the lock hash is the lockfile's sha256" {
  echo 'content-hash = "abc"' >"${WORK}/poetry.lock"
  VERSION=3.13 VERSION_FILE=.python-version POETRY_VERSION=2.5.1 WORKDIR="${WORK}" run_step resolve
  [ "$status" -eq 0 ]
  [ "$(output_of lock-hash)" = "$(sha256 "${WORK}/poetry.lock")" ]
  [ "$(output_of poetry-version)" = "2.5.1" ]
}

@test "the resolve step reads the composite's inputs" {
  [ "$(step resolve env.VERSION)" = '${{ inputs.version }}' ]
  [ "$(step resolve env.VERSION_FILE)" = '${{ inputs.version-file }}' ]
  [ "$(step resolve env.POETRY_VERSION)" = '${{ inputs.poetry-version }}' ]
  [ "$(step resolve env.WORKDIR)" = '${{ inputs.working-directory }}' ]
}

# Keys (AC5)

@test "both keys hold the platform, the arch and the exact Python version" {
  OS=Linux ARCH=X64 PYTHON_VERSION=3.13.9 POETRY_VERSION=2.5.1 LOCK_HASH=deadbeef run_step keys
  [ "$status" -eq 0 ]
  [ "$(output_of poetry-key)" = "poetry-Linux-X64-py3.13.9-2.5.1" ]
  [ "$(output_of venv-key)" = "poetry-venv-Linux-X64-py3.13.9-deadbeef" ]
}

@test "Poetry's directory is per Poetry and per Python version" {
  OS=Linux ARCH=X64 PYTHON_VERSION=3.13.9 POETRY_VERSION=2.5.1 LOCK_HASH=deadbeef run_step keys
  [ "$(output_of poetry-dir)" = "${HOME}/.cache/setup-python-poetry/2.5.1-py3.13.9" ]
}

@test "an empty part of a key fails rather than share a key" {
  for missing in OS ARCH PYTHON_VERSION POETRY_VERSION LOCK_HASH; do
    env OS=Linux ARCH=X64 PYTHON_VERSION=3.13.9 POETRY_VERSION=2.5.1 LOCK_HASH=deadbeef "${missing}=" \
      bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/keys.sh" && return 1
  done
  true
}

@test "the keys step reads the runner, setup-python and resolve" {
  [ "$(step keys env.OS)" = '${{ runner.os }}' ]
  [ "$(step keys env.ARCH)" = '${{ runner.arch }}' ]
  [ "$(step keys env.PYTHON_VERSION)" = '${{ steps.setup.outputs.python-version }}' ]
  [ "$(step keys env.POETRY_VERSION)" = '${{ steps.resolve.outputs.poetry-version }}' ]
  [ "$(step keys env.LOCK_HASH)" = '${{ steps.resolve.outputs.lock-hash }}' ]
}

# Installing Poetry (AC2)

@test "on a cache miss Poetry is installed at the exact version into its own venv" {
  stub_python
  POETRY_DIR="${WORK}/poetry" POETRY_VERSION=2.5.1 run_step install-poetry
  [ "$status" -eq 0 ]
  grep -qx "python -m venv --clear ${WORK}/poetry" "${STUB_LOG}"
  grep -q "venv-python -m pip install .*poetry==2.5.1" "${STUB_LOG}"
  [[ "$output" == *"Poetry (version 2.5.1)"* ]]
}

@test "on a cache hit Poetry is not reinstalled" {
  stub_python
  mkdir -p "${WORK}/poetry/bin"
  printf '#!/usr/bin/env bash\necho "Poetry (version 2.5.1)"\n' >"${WORK}/poetry/bin/poetry"
  chmod +x "${WORK}/poetry/bin/poetry"
  POETRY_DIR="${WORK}/poetry" POETRY_VERSION=2.5.1 run_step install-poetry
  [ "$status" -eq 0 ]
  [ ! -s "${STUB_LOG}" ]
}

@test "a restored Poetry that no longer runs is reinstalled rather than fail the job" {
  stub_python
  mkdir -p "${WORK}/poetry/bin"
  printf '#!/usr/bin/env bash\nexit 127\n' >"${WORK}/poetry/bin/poetry"
  chmod +x "${WORK}/poetry/bin/poetry"
  POETRY_DIR="${WORK}/poetry" POETRY_VERSION=2.5.1 run_step install-poetry
  [ "$status" -eq 0 ]
  grep -qx "python -m venv --clear ${WORK}/poetry" "${STUB_LOG}"
  [[ "$output" == *"Poetry (version 2.5.1)"* ]]
}

@test "Poetry goes on PATH and puts the project venv in the project" {
  stub_python
  POETRY_DIR="${WORK}/poetry" POETRY_VERSION=2.5.1 run_step install-poetry
  [ "$(cat "${GITHUB_PATH}")" = "${WORK}/poetry/bin" ]
  grep -qx "POETRY_VIRTUALENVS_IN_PROJECT=true" "${GITHUB_ENV}"
}

# This repository's smoke (AC3).

@test "the poetry smoke runs this checkout's composite on the toolchains area" {
  local job=smoke-setup-python-poetry
  [ "$(yq ".jobs.${job}.if" "${WORKFLOW}")" = "contains(fromJSON(needs.changes.outputs.areas), 'toolchains')" ]
  [ "$(yq ".jobs.${job}.steps[] | select(.id == \"poetry\") | .uses" "${WORKFLOW}")" = "./.github/actions/setup-python-poetry" ]
  [ "$(yq ".jobs.${job}.steps[] | select(.id == \"poetry\") | .with.working-directory" "${WORKFLOW}")" = "tests/fixtures/toolchains/poetry" ]
  yq ".jobs.${job}.steps[].run" "${WORKFLOW}" | grep -q 'poetry check --lock'
}

@test "the poetry fixture pins its Python version and has a lock for package-mode false" {
  [ -s "${FIXTURE}/.python-version" ]
  grep -qx 'package-mode = false' "${FIXTURE}/pyproject.toml"
  grep -q '^\[\[package\]\]' "${FIXTURE}/poetry.lock"
}
