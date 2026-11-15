#!/bin/sh
set -eu

ROOT="$(git rev-parse --show-toplevel)"
chmod +x \
	"$ROOT/tools/check.sh" \
	"$ROOT/tools/install.sh" \
	"$ROOT/tools/git-hooks/pre-commit" \
	"$ROOT/tools/git-hooks/pre-push"
git -C "$ROOT" config core.hooksPath tools/git-hooks
echo "Git hooks 已安装：core.hooksPath=tools/git-hooks"
