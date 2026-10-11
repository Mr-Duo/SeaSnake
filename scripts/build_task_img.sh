#!/bin/bash
set -euo pipefail

script_name="$(basename -- "$0")"

usage() {
    cat <<EOF
Usage: $script_name [options] [task_name ...]

Build Docker images for one or more tasks. If no task names are given,
all tasks in the default directory are built (after confirmation).

Options:
  -p, --path <dir>       Base directory containing the tasks
                         (default: the tasks folder)
  -e, --exclude <name>   Task to exclude (repeatable, or comma-separated)
  -h, --help             Show this help

Examples:
  $script_name task1 task2
  $script_name                      # build all tasks (asks for confirmation)
  $script_name -e task3 -e task4    # build all except task3 and task4
  $script_name -p /path/to/tasks task1
EOF
}

# Default: parent directory of the folder containing this script
base_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../tasks" && pwd)"

task_names=()
excludes=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--path)
            [[ $# -ge 2 ]] || { echo "Error: $1 requires a value" >&2; exit 1; }
            base_dir="$2"
            shift 2
            ;;
        --path=*)
            base_dir="${1#*=}"
            shift
            ;;
        -e|--exclude)
            [[ $# -ge 2 ]] || { echo "Error: $1 requires a value" >&2; exit 1; }
            IFS=',' read -r -a _ex <<< "$2"
            excludes+=("${_ex[@]}")
            shift 2
            ;;
        --exclude=*)
            IFS=',' read -r -a _ex <<< "${1#*=}"
            excludes+=("${_ex[@]}")
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            task_names+=("$@")
            break
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            task_names+=("$1")
            shift
            ;;
    esac
done

# Validate and normalize base_dir
if [[ ! -d "$base_dir" ]]; then
    echo "Error: Base directory not found: $base_dir" >&2
    exit 1
fi
base_dir="$(cd -- "$base_dir" && pwd)"

is_excluded() {
    local name="$1" ex
    for ex in ${excludes[@]+"${excludes[@]}"}; do
        [[ "$name" == "$ex" ]] && return 0
    done
    return 1
}

# No task names given: confirm, then discover all tasks
if [[ ${#task_names[@]} -eq 0 ]]; then
    read -r -p "Build all images of all tasks in folder $base_dir? (y/n) " answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Aborted."; exit 0 ;;
    esac

    for dir in "$base_dir"/*/; do
        [[ -f "${dir}environment/Dockerfile" ]] || continue
        task_names+=("$(basename -- "$dir")")
    done
fi

# Apply exclusions
tasks=()
for name in ${task_names[@]+"${task_names[@]}"}; do
    if is_excluded "$name"; then
        echo "Skipping excluded task: $name"
        continue
    fi
    tasks+=("$name")
done

if [[ ${#tasks[@]} -eq 0 ]]; then
    echo "Error: No tasks to build." >&2
    exit 1
fi

# Build the Docker image using the task directory as the build context
build_task() {
    local task_name="$1"
    local task_dir="$base_dir/$task_name/environment"
    local dockerfile="$task_dir/Dockerfile"
    local image_name

    image_name="$(printf '%s' "sea-snake-$task_name:latest" | tr '[:upper:]' '[:lower:]')"

    if [[ ! -f "$dockerfile" ]]; then
        echo "Error: Dockerfile not found: $dockerfile" >&2
        return 1
    fi

    echo "==> Building $image_name"
    docker build \
        --platform=linux/amd64 \
        -f "$dockerfile" \
        -t "$image_name" "$task_dir"
}

# Build every task; keep going on failure and report at the end
failed=()
for task in "${tasks[@]}"; do
    if ! build_task "$task"; then
        failed+=("$task")
    fi
done

echo
echo "Built $(( ${#tasks[@]} - ${#failed[@]} ))/${#tasks[@]} image(s) successfully."
if [[ ${#failed[@]} -gt 0 ]]; then
    echo "Failed tasks: ${failed[*]}" >&2
    exit 1
fi00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000