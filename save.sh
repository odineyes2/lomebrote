#!/bin/bash
set -e
COMFY=/workspace/runpod-slim/ComfyUI
REPO=/workspace/lomebrote

cp -u $COMFY/user/default/workflows/*.json $REPO/workflows/
cd $REPO
git add .
git status