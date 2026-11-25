#!/bin/bash
# Shared helpers for release scripts. Source with: source "$(dirname "$0")/lib.sh"
# AIDEV-NOTE: ported from murmur/scripts/lib.sh (zsh) to bash; keep the two in sync when fixing bugs.

# annotate level title message: GitHub Actions workflow command (no-op locally).
annotate() {
  [[ -z "${GITHUB_ACTIONS:-}" ]] && return 0
  local msg=${3//'%'/'%25'}
  msg=${msg//$'\r'/'%0D'}
  msg=${msg//$'\n'/'%0A'}
  printf '::%s title=%s::%s\n' "$1" "$2" "$msg"
}

# step "label" cmd args...: run quietly; on failure print output and raise an annotation.
step() {
  local label=$1; shift
  local out
  if ! out=$("$@" 2>&1); then
    printf '%s\n' "$out"
    annotate error "$label failed" "$(printf '%s\n' "$out" | tail -25)"
    return 1
  fi
  [[ -n "${VERBOSE:-}" ]] && printf '%s\n' "$out"
  return 0
}

# watched LABEL SECONDS cmd args...: like step, but kills a stalled command (exit 124) after printing evidence.
# AIDEV-NOTE: xcodebuild hung silently twice in the v1.2.0 release job, cause unknown; the sample is for diagnosis.
watched() {
  local label=$1 limit=$2 log pid rc=0 start=$SECONDS
  shift 2
  log=$(mktemp)
  "$@" > "$log" 2>&1 < /dev/null &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if (( SECONDS - start >= limit )); then
      echo "$label: no result after ${limit}s, stopping it [WATCHED-STALL]"
      # Only our own process: on a dev Mac other xcodebuilds may be running.
      [[ -n "${GITHUB_ACTIONS:-}" ]] && { ps -axo pid,ppid,stat,etime,command | grep -E 'xcodebuild|XCBBuild|SWBBuild|swift|git ' | grep -v grep | cut -c1-200 || true; }
      sample "$pid" 3 -file "$log.sample" > /dev/null 2>&1 && head -150 "$log.sample" | cut -c1-180
      echo "--- last output"; tail -25 "$log"
      pkill -9 -P "$pid" 2>/dev/null || true
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      rm -f "$log" "$log.sample"
      annotate warning "$label stalled" "Killed after ${limit}s; see the process sample in the log."
      return 124
    fi
    sleep 2
  done
  wait "$pid" || rc=$?
  if (( rc != 0 )); then
    cat "$log"
    annotate error "$label failed" "$(tail -25 "$log")"
  elif [[ -n "${VERBOSE:-}" ]]; then
    cat "$log"
  fi
  rm -f "$log"
  return "$rc"
}

# notarize FILE [STAPLE_TARGET]: submit, wait, staple; on rejection annotate Apple's issue log.
# Needs NOTARY_KEY_PATH NOTARY_KEY_ID NOTARY_ISSUER, or NOTARY_PROFILE (a `notarytool store-credentials`
# keychain profile, for local use). STAPLE_TARGET defaults to FILE.
notary_auth() {
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then echo --keychain-profile; echo "$NOTARY_PROFILE"
  else echo --key; echo "$NOTARY_KEY_PATH"; echo --key-id; echo "$NOTARY_KEY_ID"; echo --issuer; echo "$NOTARY_ISSUER"; fi
}
notarize() {
  local f=$1 target=${2:-$1} out id nstatus log="" auth
  auth=(); while IFS= read -r a; do auth+=("$a"); done < <(notary_auth)   # no mapfile: /bin/bash is 3.2
  out=$(xcrun notarytool submit "$f" "${auth[@]}" --wait --timeout 30m --output-format json 2>&1) || true
  # notarytool prints plain text (not JSON) on auth/config errors; never let parsing abort the script.
  id=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))' 2>/dev/null || true)
  nstatus=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))' 2>/dev/null || true)
  echo "  notarization ${id:-?}: ${nstatus:-unknown}"
  if [[ "$nstatus" != "Accepted" ]]; then
    [[ -n "$id" ]] && log=$(xcrun notarytool log "$id" "${auth[@]}" 2>&1 | tail -40)
    printf '%s\n%s\n' "$out" "$log"
    annotate error "Notarization of $(basename "$f") ${nstatus:-failed}" "$out
$log"
    return 1
  fi
  step "Stapling $(basename "$target")" xcrun stapler staple "$target"
}
