#!/bin/bash

set -e

# Not `omarchy remove preinstalls`: that also opts out of Omarchy's default mise
# tools, which is where claude, codex, opencode, gh, node and uv come from here.
omarchy-pkg-drop \
		aether \
		cliamp \
		libreoffice-fresh \
		monologue \
		pinta \
		obsidian
