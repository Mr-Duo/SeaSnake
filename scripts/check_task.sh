#!/bin/bash
set -euo pipefail

script_name="$(basename -- "$0")"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

usage() {
    cat <<EOF
Usage: $script_name [options] [task_name ...]

Verify tasks with harbor. If no task names are given, all tasks in the default
directory are verified (after confirmation).

Options:
  -p, --path <dir>       Base directory containing the tasks
                        (default: the tasks folder)
  -e, --exclude <name>   Task to exclude (repeatable, or comma-separated)
  -a, --agent <name>     Agent name (default: mini-swe-agent)
  -m, --model <name>     Model name (default: openrouter/deepseek/deepseek-v3.2)
  -h, --help             Show this help

Examples:
  $script_name task1 task2
  $script_name                          # run all tasks (asks for confirmation)
  $script_name -e task3 -e task4        # run all except task3 and task4
  $script_name -p /path/to/tasks -a claude-code -m anthropic/claude-sonnet-4 task1
EOF
}

# Defaults
base_dir="$(cd -- "$script_dir/../tasks" && pwd)"
agent_name="mini-swe-agent"
model_name="openrouter/deepseek/deepseek-v4.1-flash"
default_skill="$script_dir/snapshot_management_skill"

task_names=()
excludes=()

require_value() {
    [[ $2 -ge 2 ]] || { echo "Error: $1 requires a value" >&2; exit 1; }
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--path)
            require_value "$1" $#
            base_dir="$2"; shift 2 ;;
        --path=*)
            base_dir="${1#*=}"; shift ;;
        -e|--exclude)
            require_value "$1" $#
            IFS=',' read -r -a _ex <<< "$2"
            excludes+=("${_ex[@]}")
            shift 2 ;;
        --exclude=*)
            IFS=',' read -r -a _ex <<< "${1#*=}"
            excludes+=("${_ex[@]}")
            shift ;;
        -a|--agent)
            require_value "$1" $#
            agent_name="$2"; shift 2 ;;
        --agent=*)
            agent_name="${1#*=}"; shift ;;
        -m|--model)
            require_value "$1" $#
            model_name="$2"; shift 2 ;;
        --model=*)
            model_name="${1#*=}"; shift ;;
        -h|--help)
            usage; exit 0 ;;
        --)
            shift
            task_names+=("$@")
            break ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 1 ;;
        *)
            task_names+=("$1"); shift ;;
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
    read -r -p "Run all tasks in folder $base_dir? (y/n) " answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Aborted."; exit 0 ;;
    esac

    for dir in "$base_dir"/*/; do
        # A task folder has a task.toml or an environment/Dockerfile
        if [[ -f "${dir}task.toml" || -f "${dir}environment/Dockerfile" ]]; then
            task_names+=("$(basename -- "$dir")")
        fi
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
    echo "Error: No tasks to run." >&2
    exit 1
fi

run_task() {
    local task_name="$1"
    local task_path="$base_dir/$task_name"

    if [[ ! -d "$task_path" ]]; then
        echo "Error: Task not found: $task_path" >&2
        return 1
    fi

    echo "==> Running $task_name (agent: $agent_name, model: $model_name)"
    harbor check \
        -a "$agent_name" \
        -m "$model_name" \
        "$task_path"
    }

# Run every task; keep going on failure and report at the end
failed=()
for task in "${tasks[@]}"; do
    if ! run_task "$task"; then
        failed+=("$task")
    fi
done

echo
echo "Ran $(( ${#tasks[@]} - ${#failed[@]} ))/${#tasks[@]} task(s) successfully."
if [[ ${#failed[@]} -gt 0 ]]; then
    echo "Failed tasks: ${failed[*]}" >&2
    exit 1
fi
