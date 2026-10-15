#!/bin/bash

harbor run \
    --path tasks \
    -a "agents.snap_codex:Codex" \
    -m "openrouter/z-ai/glm-4.5-air" \
    --n-concurrent 8 \
    # --agent-timeout-multiplier 0.05
