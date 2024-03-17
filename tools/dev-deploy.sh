#!/bin/bash

script_path=$(cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(realpath $script_path/..)
SCRIPT="$PROJECT_DIR/tools/deploy.sh"

export PROJECT_DIR

bash $SCRIPT "$@"