#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_PATH="$HOME/.local/share/omarchy-supplement-resources"

if [ -d "$RESOURCES_PATH" ]; then
	echo "Existing $RESOURCES_PATH directory found, deleting it."
	rm -rf $RESOURCES_PATH
fi

cp -r $SCRIPT_DIR/resources $RESOURCES_PATH