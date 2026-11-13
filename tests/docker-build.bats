#!/usr/bin/env bats
#
# The docker-build composite (spec CI-010, issue #11). buildx is not run here:
# the tests read the wiring from action.yml and run the composite's resolve
# script the way a composite runs it. The smoke jobs in lint.yml build for real.

ACTION="${BATS_TEST_DIRNAME}/../.github/actions/docker-build/action.yml"
WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/lint.yml"

step() { yq ".runs.steps[] | select(.id == \"$1\") | .$2" "${ACTION}"; }

setup() {
  export GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/output"
  : >"${GITHUB_OUTPUT}"
  step resolve run >"${BATS_TEST_TMPDIR}/resolve.sh"
  export IMAGE=app CACHE_SCOPE="" CACHE_MODE=max CACHE_FROM="" CACHE_TO="" LOAD=false PUSH=false PUSH_BY_DIGEST=false CACHE_WRITE=true
}

resolve() { run bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/resolve.sh"; }

# Reads an output in either form GitHub accepts: name=value, or name<<DELIM
# followed by lines up to DELIM. The last write of a name wins.
output_of() {
  awk -v k="$1" '
    d != "" { if ($0 == d) { d = ""; v[k] = buf; found = 1 } else { buf = buf (buf == "" ? "" : "\n") $0 }; next }
    index($0, k "<<") == 1 { d = substr($0, length(k) + 3); buf = ""; next }
    index($0, k "=") == 1 { v[k] = substr($0, length(k) + 2); found = 1 }
    END { if (found) print v[k] }' "${GITHUB_OUTPUT}"
}

# Shape (AC1)

@test "the inputs and their defaults" {
  [ "$(yq '.inputs.image.required' "${ACTION}")" = "true" ]
  [ "$(yq '.inputs.context.default' "${ACTION}")" = "." ]
  [ "$(yq '.inputs.load.default' "${ACTION}")" = "false" ]
  [ "$(yq '.inputs.push.default' "${ACTION}")" = "false" ]
  [ "$(yq '.inputs.cache-scope.default' "${ACTION}")" = "" ]
  [ "$(yq '.inputs.cache-mode.default' "${ACTION}")" = "max" ]
  [ "$(yq '.inputs.cache-from.default' "${ACTION}")" = "" ]
  [ "$(yq '.inputs.cache-to.default' "${ACTION}")" = "" ]
}

@test "the outputs map to the build and resolve steps" {
  [ "$(yq '.outputs.digest.value' "${ACTION}")" = '${{ steps.build.outputs.digest }}' ]
  [ "$(yq '.outputs.imageid.value' "${ACTION}")" = '${{ steps.build.outputs.imageid }}' ]
  [ "$(yq '.outputs.cache-scope.value' "${ACTION}")" = '${{ steps.resolve.outputs.scope }}' ]
}

@test "every third-party action is pinned by full SHA with its tag as a comment" {
  local uses pinned
  uses=$(grep -cE '^\s+uses: [^.]' "${ACTION}")
  pinned=$(grep -cE '^\s+uses: [a-z0-9-]+/[a-z0-9-]+@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$' "${ACTION}")
  [ "${uses}" -eq 2 ]
  [ "${uses}" -eq "${pinned}" ]
}

@test "build-push-action builds with the resolved cache and the caller's inputs" {
  [ "$(step build uses | cut -d@ -f1)" = "docker/build-push-action" ]
  [ "$(step build with.cache-from)" = '${{ steps.resolve.outputs.cache-from }}' ]
  [ "$(step build with.cache-to)" = '${{ steps.resolve.outputs.cache-to }}' ]
  [ "$(step build with.load)" = '${{ inputs.load }}' ]
  [ "$(step build with.push)" = '${{ inputs.push }}' ]
  [ "$(step build with.context)" = '${{ inputs.context }}' ]
  [ "$(step build with.tags)" = "\${{ steps.resolve.outputs.by-digest != 'true' && (inputs.tags || inputs.image) || '' }}" ]
  [ "$(step build with.outputs)" = '${{ steps.resolve.outputs.outputs }}' ]
}

@test "the composite never logs in" {
  run grep -E 'login-action|docker login' "${ACTION}"
  [ "$status" -ne 0 ]
}

@test "the resolve script runs under bash and reads inputs only through env" {
  [ "$(step resolve shell)" = "bash" ]
  run bash -c "yq '.runs.steps[] | select(.id == \"resolve\") | .run' '${ACTION}' | grep -F '\${{'"
  [ "$status" -ne 0 ]
}

# Cache scope (AC1)

@test "the cache scope defaults to the image name and a hash of it" {
  resolve
  [ "$status" -eq 0 ]
  [ "$(output_of scope)" = "app-a172cedc" ]
  [ "$(output_of cache-from)" = "type=gha,scope=app-a172cedc" ]
  [ "$(output_of cache-to)" = "type=gha,scope=app-a172cedc,mode=max" ]
}

@test "two image names that sanitize alike still get two scopes" {
  IMAGE=ghcr.io/owner/a/b resolve
  local first; first=$(output_of scope)
  : >"${GITHUB_OUTPUT}"
  IMAGE=ghcr.io/owner/a-b resolve
  [ "${first}" != "$(output_of scope)" ]
}

@test "two images in one repository get two scopes" {
  IMAGE=docker.io/owner/kubelab-api resolve
  local api; api=$(output_of scope)
  : >"${GITHUB_OUTPUT}"
  IMAGE=docker.io/owner/kubelab-web resolve
  [ "${api}" != "$(output_of scope)" ]
}

@test "a registry path becomes a scope with no slash or colon" {
  IMAGE=ghcr.io/owner/app resolve
  [ "$status" -eq 0 ]
  [[ "$(output_of scope)" =~ ^ghcr\.io-owner-app-[0-9a-f]{8}$ ]]
}

@test "an explicit scope wins over the image, as given" {
  CACHE_SCOPE=smoke-1 resolve
  [ "$(output_of scope)" = "smoke-1" ]
}

@test "an explicit scope is sanitized like a derived one" {
  CACHE_SCOPE="owner/app:1" resolve
  [ "$status" -eq 0 ]
  [ "$(output_of scope)" = "owner-app-1" ]
}

@test "no input value leaves the scope empty" {
  local value
  for value in "" " " "  "; do
    : >"${GITHUB_OUTPUT}"
    CACHE_SCOPE="${value}" resolve
    [ "$status" -eq 0 ]
    [ "$(output_of scope)" = "app-a172cedc" ]
  done
  for value in "" " " "/" ":"; do
    : >"${GITHUB_OUTPUT}"
    IMAGE="${value}" CACHE_SCOPE="" resolve
    [ "$status" -ne 0 ]
    [[ "$output" == *"scope"* ]]
  done
}

@test "the cache mode is passed through, and an unknown mode fails" {
  CACHE_MODE=min resolve
  [ "$(output_of cache-to)" = "type=gha,scope=app-a172cedc,mode=min" ]
  CACHE_MODE=all resolve
  [ "$status" -ne 0 ]
}

@test "cache-from and cache-to overrides replace the gha default" {
  CACHE_FROM="type=registry,ref=r/app:cache" CACHE_TO="type=registry,ref=r/app:cache,mode=max" resolve
  [ "$status" -eq 0 ]
  [ "$(output_of cache-from)" = "type=registry,ref=r/app:cache" ]
  [ "$(output_of cache-to)" = "type=registry,ref=r/app:cache,mode=max" ]
}

@test "a cache list, one entry a line, reaches the build whole" {
  CACHE_FROM=$'type=registry,ref=r/app:cache\ntype=gha,scope=app' CACHE_TO=$'type=gha,scope=app,mode=max\ntype=inline' resolve
  [ "$status" -eq 0 ]
  [ "$(output_of cache-from)" = $'type=registry,ref=r/app:cache\ntype=gha,scope=app' ]
  [ "$(output_of cache-to)" = $'type=gha,scope=app,mode=max\ntype=inline' ]
  run grep -c '^type=' "${GITHUB_OUTPUT}"
  [ "$output" -eq 4 ]
}

@test "cache-write false reads the cache and writes none" {
  local v
  for v in false " False" FALSE; do
    : >"${GITHUB_OUTPUT}"
    CACHE_WRITE="${v}" resolve
    [ "$status" -eq 0 ]
    [[ "$(output_of cache-from)" == type=gha,scope=app-* ]]
    [ "$(output_of cache-to)" = "" ]
  done
}

@test "a cache-write that is neither true nor false fails instead of skipping the write" {
  local v
  for v in ture yes on 1; do
    CACHE_WRITE="${v}" resolve
    [ "$status" -ne 0 ]
    [[ "$output" == *"cache-write"* ]]
  done
  CACHE_WRITE=" TRUE " resolve
  [ "$status" -eq 0 ]
}

@test "cache-write false with a cache-to override fails, since the two disagree" {
  CACHE_WRITE=false CACHE_TO="type=registry,ref=r/app:cache" resolve
  [ "$status" -ne 0 ]
  [[ "$output" == *"cache-write"* ]]
}

@test "the composite passes the caller's labels and its cache-write input to the build" {
  [ "$(yq '.inputs.cache-write.default' "${ACTION}")" = "true" ]
  [ "$(yq '.inputs.labels.default' "${ACTION}")" = "" ]
  [ "$(step resolve env.CACHE_WRITE)" = '${{ inputs.cache-write }}' ]
  [ "$(step build with.labels)" = '${{ inputs.labels }}' ]
}

# load and push

@test "load and push together fail, since a loaded image is never pushed" {
  LOAD=true PUSH=true resolve
  [ "$status" -ne 0 ]
  [[ "$output" == *"load"* && "$output" == *"push"* ]]
}

@test "load and push are read the way build-push-action reads them" {
  local l p
  for l in True TRUE " true "; do
    for p in true " True"; do
      LOAD="${l}" PUSH="${p}" resolve
      [ "$status" -ne 0 ]
    done
  done
}

@test "load alone and push alone pass" {
  LOAD=true resolve
  [ "$status" -eq 0 ]
  LOAD=false PUSH=true resolve
  [ "$status" -eq 0 ]
}

# push-by-digest, which docker-publish.yml relies on

@test "push-by-digest pushes the image under its name and no tag" {
  IMAGE=docker.io/owner/app PUSH_BY_DIGEST=" True" resolve
  [ "$status" -eq 0 ]
  [ "$(output_of by-digest)" = "true" ]
  [ "$(output_of outputs)" = "type=image,name=docker.io/owner/app,push-by-digest=true,name-canonical=true,push=true" ]
}

@test "push-by-digest excludes load and push, which would name a tag" {
  PUSH_BY_DIGEST=true LOAD=true resolve
  [ "$status" -ne 0 ]
  PUSH_BY_DIGEST=true PUSH=TRUE resolve
  [ "$status" -ne 0 ]
}

@test "without push-by-digest the composite names no output and keeps its tags" {
  resolve
  [ "$(output_of by-digest)" = "false" ]
  [ "$(output_of outputs)" = "" ]
}

# Smoke (AC3)

@test "the docker smokes run behind the docker area and stay in gate's needs" {
  local smoke
  for smoke in smoke-docker-build smoke-docker-build-warm; do
    [ "$(yq ".jobs.${smoke}.if" "${WORKFLOW}")" = "contains(fromJSON(needs.changes.outputs.areas), 'docker')" ]
    yq '.jobs.gate.needs[]' "${WORKFLOW}" | grep -qx "${smoke}"
  done
  [ "$(yq '.jobs.smoke-docker-build-warm.needs | sort | join(",")' "${WORKFLOW}")" = "changes,smoke-docker-build" ]
}

@test "the docker area covers the composite and its fixture" {
  yq '.jobs.changes.steps[] | select(.id == "changes") | .with.filters' "${WORKFLOW}" | yq '.docker[]' | grep -qx '.github/actions/docker-build/\*\*'
  yq '.jobs.changes.steps[] | select(.id == "changes") | .with.filters' "${WORKFLOW}" | yq '.docker[]' | grep -qx 'tests/fixtures/docker-build/\*\*'
}

@test "both smokes build into one per-run scope, so the cold build starts cold" {
  local smoke
  for smoke in smoke-docker-build smoke-docker-build-warm; do
    [ "$(yq ".jobs.${smoke}.steps[] | select(.id == \"build\") | .uses" "${WORKFLOW}")" = "./.github/actions/docker-build" ]
    [ "$(yq ".jobs.${smoke}.steps[] | select(.id == \"build\") | .with.cache-scope" "${WORKFLOW}")" = 'smoke-${{ github.run_id }}-${{ github.run_attempt }}' ]
  done
}

@test "the warm smoke fails above 30 seconds and on a layer rebuilt instead of restored" {
  local runs
  runs=$(yq '.jobs.smoke-docker-build-warm.steps[].run | select(. != null)' "${WORKFLOW}")
  grep -q -- '-gt 30' <<<"${runs}"
  grep -q 'COLD_STAMP' <<<"${runs}"
}
