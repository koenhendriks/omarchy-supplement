#!/bin/bash

set -e

curl -L https://github.com/shaharia-lab/slackcli/releases/latest/download/slackcli-linux -o slackcli
chmod +x slackcli
mkdir -p ~/.local/bin && mv slackcli ~/.local/bin/