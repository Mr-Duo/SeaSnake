# Snapshot Management Skill

## Purpose

Manage before-and-after snapshots for code changes using only Bash `cp`
and `rm` for snapshot creation, restoration, and deletion. Snapshots
must preserve the exact original and final file contents.

## Mandatory Rules

-   Use Bash `cp` exclusively to create before-snapshots and
    after-snapshots.
-   Use Bash `cp` to restore a reverted file from its verified
    before-snapshot.
-   Use Bash `rm` only to delete exact, verified task-specific snapshots
    or files that were created by the current task and are being fully
    reverted.
-   Use read-only commands such as `cmp` to verify snapshots.
-   Do not use Python, `mv`, `install`, `tee`, redirection, `sed`,
    `awk`, editors, or other methods to generate, copy, restore, or
    modify snapshot contents.
-   These restrictions apply to snapshot operations only; they do not
    prohibit normal source-code editing, testing, inspection, or service
    verification.
-   Never overwrite or delete unrelated files or pre-existing user data.

## Snapshot Locations

-   Before snapshots: `/app/output/before/`
-   After snapshots: `/app/output/after/`

Create the directories if needed. Before writing a snapshot, check that
its destination does not contain an unrelated pre-existing file.

## Filename Convention

Replace every `/` in the source file's absolute path with `%`, then
place the resulting filename in the appropriate snapshot directory.

Example source file:

`/app/path/example.py`

-   Before: `/app/output/before/%app%path%example.py`
-   After: `/app/output/after/%app%path%example.py`

Use the same snapshot filename in both directories. Detect filename
collisions before writing snapshots. If a collision exists, use a
deterministic, collision-free extension and document the mapping.

## Workflow

### 1. Identify files

Identify all existing source, test, and other application files that are
expected to change. Determine their absolute paths and corresponding
snapshot paths.

### 2. Capture original versions before any edits

Before modifying any code file, create and verify before-snapshots for
all existing files intended for modification.

Example:

``` bash
mkdir -p /app/output/before /app/output/after
cp -- /app/path/example.py /app/output/before/%app%path%example.py
cmp -- /app/path/example.py /app/output/before/%app%path%example.py
```

Do not begin code modifications until all required before-snapshots have
been created and verified. A before-snapshot must contain the exact
original contents from before the agent's first modification. Never
replace it with an intermediate version.

If a snapshot cannot be safely created or verified, do not modify that
source file until the issue is resolved.

### 3. Make changes

Implement the fix and any necessary tests. A file may be changed
multiple times, but its before-snapshot must remain unchanged.

### 4. Capture final versions

After all intended changes to a file are complete, including the final
fix and any revisions, create or refresh its after-snapshot using `cp`.

``` bash
cp -- /app/path/example.py /app/output/after/%app%path%example.py
cmp -- /app/path/example.py /app/output/after/%app%path%example.py
```

If the source file changes again, refresh the after-snapshot with `cp`
and verify it again. Never report a stale after-snapshot as final.

Include every modified source file, modified test file, and other
modified application file needed to document the fix. Do not include
unchanged files unless specifically necessary.

### 5. Newly created files

For a new file, create an empty before-snapshot by first creating a
deliberately empty temporary file outside both snapshot directories,
then copying it with `cp`. Verify that the before-snapshot is empty.
Once the new file is finalized, copy it to the after directory with `cp`
and verify the copy.

Do not overwrite unrelated files when creating the temporary file or
snapshots.

### 6. Deleted files

Avoid deleting files unless essential. If deletion is necessary, copy
the original file to the before directory before deleting it. After the
deletion is finalized, create an empty after-snapshot by copying a
deliberately empty temporary file from outside both snapshot
directories. Verify both snapshots and document the deletion.

## Reverting Changes

If all changes made by the agent to an existing file are reverted:

1.  Verify that the before-snapshot belongs to the current task and
    contains the original version.
2.  Restore the source file by copying the before-snapshot back with
    `cp`.
3.  Verify the restored file with `cmp`.
4.  Delete the exact task-specific before- and after-snapshot paths with
    `rm`.
5.  Verify that both task-specific snapshots have been removed.

Example:

``` bash
cp -- /app/output/before/%app%path%example.py /app/path/example.py
cmp -- /app/output/before/%app%path%example.py /app/path/example.py
rm -- /app/output/before/%app%path%example.py /app/output/after/%app%path%example.py
```

Run these commands only after confirming that both snapshots exist,
belong to the current task, and are safe to remove.

Additional rules:

-   Never use broad wildcards or directory-wide deletion to remove
    snapshots.
-   Do not remove snapshots belonging to files with retained changes.
-   If only some changes are reverted and other changes remain, keep
    both snapshots and refresh the after-snapshot after the retained
    changes are finalized.
-   If a newly created file is fully reverted, remove the task-created
    file and its exact task-specific snapshots with `rm`, after
    verifying ownership.
-   If a deleted file is restored, use `cp` from its original
    before-snapshot. Remove snapshots only if the file has no remaining
    changes.
-   Never delete unrelated user files or pre-existing snapshots.

## Final Validation

For every retained modification, verify that:

-   The before-snapshot matches the original version captured before any
    edits.
-   The after-snapshot matches the final source file after every change.
-   The snapshot paths follow the naming convention and correspond to
    the correct absolute source paths.
-   The after-snapshot includes the final vulnerability fix rather than
    an intermediate implementation.
-   No stale snapshots remain for files whose changes were fully
    reverted.

Use read-only comparison commands such as `cmp` for verification. Do not
modify snapshot contents during verification.
