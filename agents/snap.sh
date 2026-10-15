#!/bin/bash

set -u

WORKDIR=${SNAP_WORKDIR:-/app}
ROOT=${SNAP_ROOT:-/do-not-touch}
OUT=$ROOT/output
BEFORE=$OUT/before
AFTER=$OUT/after
PATCH=$OUT/patch
rc=0

die()  { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; rc=1; }
info() { echo "INFO: $*"; }

cmd_before() { 
  info "Starting snapshot"
  info "Working directory: $WORKDIR"

  find "$WORKDIR" -name .git -prune -exec rm -rf -- {} + || warn "Cannot delete .git folders"
  find "$WORKDIR" -name .gitignore -type f -delete || warn "Cannot delete .gitignore files"

  # Initialize a new repository
  git -C "$WORKDIR" init || die "Failed to init git repo to track"

  # Trust this repository directory
  git config --global --add safe.directory "$WORKDIR"

  # Create the initial checkpoint
  git -C "$WORKDIR" add -A || die "Failed to add before snapshot"
  git -C "$WORKDIR" \
      -c user.name="Checkpoint" \
      -c user.email="checkpoint@localhost" \
      commit -m "Initial checkpoint" 
}

cmd_after() {
  # Create the snapshot directories.
  mkdir -p -- "$BEFORE" "$AFTER" "$PATCH" || die "cannot create $BEFORE $AFTER $PATCH"
  
  # Stage all changes so Git can include newly created files.
  # Exclude the generated output directory.
  git add -A -- . || die "Failed to add after snapshot"

  # Recreate the snapshot directories.
  mkdir -p -- "$BEFORE" "$AFTER" "$PATCH" || die "cannot create $BEFORE $AFTER $PATCH"

  # Compare everything against the initial checkpoint.
  git diff HEAD --no-ext-diff --no-renames \
      --name-only -z -- . | \
  while IFS= read -r -d '' file; do
      # Flatten the path: a/b/example.py -> %a%b%example.py
      flat_file="${WORKDIR//\//%}%${file//\//%}"

      before_file="$BEFORE/$flat_file"
      after_file="$AFTER/$flat_file"
      patch_file="$PATCH/$flat_file.patch"

      # Save the patch.
      git diff HEAD --no-ext-diff --no-renames -- "$file" \
          > "$patch_file" || die "Failed to generate patch file $patch_file"

      # Save the original version, or an empty file if it was added.
      if git cat-file -e "HEAD:$file" 2>/dev/null; then
          git show "HEAD:$file" > "$before_file" \
              || die "Failed to generate before file $before_file"
      else
          : > "$before_file"
      fi

      # Save the final version, or an empty file if it was deleted.
      if [ -f "$file" ] || [ -L "$file" ]; then
          cp -a -- "$file" "$after_file" \
              || die "Failed to generate after file $after_file"
      else
          : > "$after_file"
      fi
  done
}

case ${1:-} in
  before) cmd_before ;;
  after)  cmd_after ;;
  *) sed -n '2,23p' "$0" | cut -c3-; exit 2 ;;
esac
exit $rc