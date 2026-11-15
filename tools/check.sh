#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python}"
GODOT_BIN="${GODOT_BIN:-U:/Godot_ver/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"

compile_check() {
	if [[ ! -f "$GODOT_BIN" ]]; then
		echo "找不到 Godot：$GODOT_BIN（用 GODOT_BIN 指定）" >&2
		return 2
	fi

	local tmp
	tmp="$(mktemp -d)"
	local out="$tmp/out.txt"
	local isolated="$tmp/user_data"
	mkdir -p "$isolated"

	if [[ ! -f "$ROOT/.godot/global_script_class_cache.cfg" ]]; then
		echo "Godot 缓存不存在，先导入一次..." >&2
		(
			export APPDATA="$isolated"
			export XDG_DATA_HOME="$isolated"
			"$GODOT_BIN" --headless --path "$ROOT" --import
		) > "$tmp/import.txt" 2>&1 || true
	fi

	(
		export APPDATA="$isolated"
		export XDG_DATA_HOME="$isolated"
		"$GODOT_BIN" --headless --path "$ROOT" \
			res://tools/compile_check/check_scene.tscn \
			--quit-after 1200
	) > "$out" 2>&1 || true

	if grep -Eq "SCRIPT ERROR: (Parse|Compile) Error|Failed to load script|Failed to instantiate an autoload" "$out"; then
		echo "编译检查失败：" >&2
		grep -E "SCRIPT ERROR: (Parse|Compile) Error|Failed to load script|Failed to instantiate an autoload|at: GDScript::reload" "$out" | head -80 >&2 || true
		rm -rf "$tmp"
		return 1
	fi

	if grep -Eq "CHECK_FAILED [1-9]" "$out"; then
		echo "编译检查失败：" >&2
		grep -E "CHECK_FAILED|CHECK_FAIL" "$out" | head -80 >&2 || true
		rm -rf "$tmp"
		return 1
	fi

	grep -E "CHECK_TOTAL|CHECK_FAILED" "$out" | tail -2 || true
	rm -rf "$tmp"
}

case "${1:---all}" in
	--file)
		shift
		if [[ $# -eq 0 ]]; then
			echo "用法：tools/check.sh --file <path>..." >&2
			exit 2
		fi
		args=()
		for path in "$@"; do
			args+=(--file "$path")
		done
		exec "$PYTHON_BIN" -X utf8 -I "$ROOT/tools/lint/runner.py" \
			--root "$ROOT" "${args[@]}"
		;;
	--staged)
		"$PYTHON_BIN" -X utf8 -I "$ROOT/tools/lint/runner.py" \
			--root "$ROOT" --staged
		compile_check
		;;
	--all)
		"$PYTHON_BIN" -X utf8 -I -m unittest discover \
			-s "$ROOT/tools/lint/tests" -v
		"$PYTHON_BIN" -X utf8 -I "$ROOT/tools/lint/runner.py" \
			--root "$ROOT" --all
		compile_check
		;;
	--help|-h)
		echo "用法：tools/check.sh [--file <path>... | --staged | --all]"
		;;
	*)
		echo "未知参数：$1" >&2
		exit 2
		;;
esac
