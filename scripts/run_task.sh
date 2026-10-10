#!/bin/bash

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

task_name="$1"
agent_name="${2:-mini-swe-agent}"
model_name="${3:-openrouter/deepseek/deepseek-v3.2}"

harbor run \
    -a "$agent_name" \
    -m "$model_name" \
    -p "$task_name" \
    # --skill "$script_dir"/"snapshot_management_skill"
