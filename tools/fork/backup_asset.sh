#!/bin/bash
# Fork doctoralvarez/Nyxian — version 1.1.0
# Changelog:
#  - 1.1.0 (2026-11-09): restore-like TAG 'PATTERN': the newest asset matching a
#    pattern (a toolchain built with another Xcode, when the exact one is missing).
#  - 1.0.0 (2026-11-09): keeps big build pieces (the LLVM/Swift toolchain, the
#    Python runtime, the IPA, source bundles) as release assets of your PRIVATE
#    backup repository, so CI and the app work even if GitHub's cache is gone
#    or emexLabs' sites and repositories are not there any more. Files over
#    1.9 GB go up in parts (GitHub's limit is 2 GB per file).
#
# usage: backup_asset.sh has     TAG NAME
#        backup_asset.sh save    TAG NAME PATH…   (a folder or files: tar.gz; one .ipa/.zip/.bundle file: as is)
#        backup_asset.sh restore TAG NAME          (into the current folder)
#        backup_asset.sh restore-like TAG 'PATTERN' (the newest asset whose name matches the shell pattern)
# env:   GH_TOKEN (Contents: read and write on the repository), BACKUP_REPO (owner/repo)
set -euo pipefail

command=${1:-}
tag=${2:-}
name=${3:-}
repo=${BACKUP_REPO:-doctoralvarez/nyxian-sdk}
part_size=1900m

if [ -z "${GH_TOKEN:-}" ]; then
  echo "backup: no token (secret SDK_REPO_TOKEN) — skipped"
  exit 3
fi

assets() {
  gh release view "$tag" -R "$repo" --json assets -q '.assets[].name' 2>/dev/null || true
}

case "$command" in
  has)
    assets | grep -Eq "^${name}(\.part[0-9]+)?$"
    ;;
  save)
    shift 3
    if assets | grep -Eq "^${name}(\.part[0-9]+)?$"; then
      echo "backup: $name is already on $repo ($tag)"
      exit 0
    fi
    work=$(mktemp -d)
    if [ $# -eq 1 ] && [ -f "$1" ]; then
      cp "$1" "$work/$name"
    else
      tar -czf "$work/$name" "$@"
    fi
    size=$(wc -c < "$work/$name" | tr -d ' ')
    gh release view "$tag" -R "$repo" >/dev/null 2>&1 || \
      gh release create "$tag" -R "$repo" --title "$tag" --notes "Backups made by doctoralvarez/Nyxian's CI (tools/fork/backup_asset.sh). Private, personal use." >/dev/null
    if [ "$size" -gt 1990000000 ]; then
      (cd "$work" && split -b "$part_size" -d -a 2 "$name" "$name.part")
      rm "$work/$name"
    fi
    gh release upload "$tag" -R "$repo" "$work"/* --clobber
    echo "backup: saved $name ($size bytes) on $repo ($tag)"
    rm -rf "$work"
    ;;
  restore-like)
    pattern=$name
    match=""
    while IFS= read -r asset; do
      base=${asset%.part[0-9][0-9]}
      # shellcheck disable=SC2053
      [[ $base == $pattern ]] && match=$base
    done < <(gh release view "$tag" -R "$repo" --json assets -q '.assets | sort_by(.createdAt) | .[].name' 2>/dev/null || true)
    if [ -z "$match" ]; then
      echo "backup: nothing like $pattern on $repo ($tag)"
      exit 1
    fi
    echo "backup: the closest is $match"
    exec "$0" restore "$tag" "$match"
    ;;
  restore)
    work=$(mktemp -d)
    found=$(assets | grep -E "^${name}(\.part[0-9]+)?$" | sort || true)
    if [ -z "$found" ]; then
      echo "backup: $name is not on $repo ($tag)"
      exit 1
    fi
    for asset in $found; do
      gh release download "$tag" -R "$repo" -p "$asset" -D "$work" --clobber
    done
    if [ -f "$work/$name" ]; then
      file="$work/$name"
    else
      cat "$work/$name".part* > "$work/$name"
      file="$work/$name"
    fi
    case "$name" in
      *.tar.gz) tar -xzf "$file" ;;
      *) cp "$file" "./$name" ;;
    esac
    echo "backup: restored $name from $repo ($tag)"
    rm -rf "$work"
    ;;
  *)
    sed -n '11,16p' "$0"
    exit 2
    ;;
esac
