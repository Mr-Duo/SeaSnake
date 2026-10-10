#!/bin/bash

task_name="$1"
agent_name="${2:-mini-swe-agent}"
model_name="${3:-openrouter/deepseek/deepseek-v4.1-flash}"

harbor check \
    -a "$agent_name" \
    -m "$model_name" \
    "$task_name"
