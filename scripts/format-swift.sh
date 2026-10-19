#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
xcrun swift-format format --in-place --configuration "$REPO_ROOT/.swift-format" --recursive "$REPO_ROOT/Apps"
