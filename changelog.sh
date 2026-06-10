#!/usr/bin/env bash
set -euo pipefail

output_file="${1:-CHANGELOG.md}"
repo_name="$(basename "$(git rev-parse --show-toplevel)")"
latest_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
today="$(date +%Y-%m-%d)"

if [[ -n "$latest_tag" ]]; then
  range="${latest_tag}..HEAD"
  range_label="Changes since ${latest_tag}"
else
  range=""
  range_label="All commits"
fi

added=()
fixed=()
changed=()
removed=()

normalize_subject() {
  local subject="$1"
  subject="$(printf '%s' "$subject" | sed -E 's/^(feat|fix|docs|chore|refactor|test|style|perf|build|ci)(\([^)]+\))?!?:[[:space:]]*//')"
  printf '%s' "$subject"
}

add_entry() {
  local category="$1"
  local line="$2"

  case "$category" in
    added) added+=("$line") ;;
    fixed) fixed+=("$line") ;;
    removed) removed+=("$line") ;;
    *) changed+=("$line") ;;
  esac
}

while IFS='|' read -r hash subject; do
  [[ -z "${subject:-}" ]] && continue

  lower_subject="$(printf '%s' "$subject" | tr '[:upper:]' '[:lower:]')"
  prefix="${lower_subject%%:*}"
  prefix="${prefix%%(*}"
  clean_subject="$(normalize_subject "$subject")"
  entry="- ${clean_subject} (${hash})"

  case "$prefix" in
    feat|add|added|create|implement) add_entry added "$entry" ;;
    fix|fixed|bug|bugfix|resolve|patch) add_entry fixed "$entry" ;;
    remove|removed|delete|deleted|drop|dropped|deprecate) add_entry removed "$entry" ;;
    *)
      case "$lower_subject" in
    *" add "*|*" added "*|*" create "*|*" implement "*) add_entry added "$entry" ;;
    *" fix "*|*" fixed "*|*" bug "*|*" resolve "*) add_entry fixed "$entry" ;;
    *" remove "*|*" removed "*|*" delete "*|*" drop "*) add_entry removed "$entry" ;;
    *) add_entry changed "$entry" ;;
      esac
      ;;
  esac
done < <(git log --no-merges --date-order --format='%h|%s' ${range})

{
  printf '# Changelog\n\n'
  printf '## %s - %s\n\n' "$today" "$range_label"
  printf 'Repository: `%s`\n\n' "$repo_name"

  if (( ${#added[@]} == 0 && ${#fixed[@]} == 0 && ${#changed[@]} == 0 && ${#removed[@]} == 0 )); then
    printf 'No commits found for this range.\n'
    exit 0
  fi

  if (( ${#added[@]} > 0 )); then
    printf '### Added\n'
    printf '%s\n' "${added[@]}"
    printf '\n'
  fi

  if (( ${#fixed[@]} > 0 )); then
    printf '### Fixed\n'
    printf '%s\n' "${fixed[@]}"
    printf '\n'
  fi

  if (( ${#changed[@]} > 0 )); then
    printf '### Changed\n'
    printf '%s\n' "${changed[@]}"
    printf '\n'
  fi

  if (( ${#removed[@]} > 0 )); then
    printf '### Removed\n'
    printf '%s\n' "${removed[@]}"
    printf '\n'
  fi
} > "$output_file"

printf 'Generated %s from %s.\n' "$output_file" "$range_label"
