#!/bin/bash
set -euo pipefail

# Resolve the directory containing this script
base_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

task_name="${1:?Usage: $0 <task_name>}"

image_name="sea-snake-$task_name:latest"
image_name="$(printf '%s' "$image_name" | tr '[:upper:]' '[:lower:]')"
task_dir="$base_dir/$task_name"/environment
dockerfile="$task_dir/Dockerfile"

# Validate the Dockerfile
if [[ ! -f "$dockerfile" ]]; then
    echo "Error: Dockerfile not found: $dockerfile" >&2
    exit 1
fi

# Build the Docker image using the task directory as the build context
docker build -f "$dockerfile" -t "$image_name" "$task_dir"