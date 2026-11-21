#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python}"
GODOT_BIN="${GODOT_BIN:-U:/Godot_ver/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
GODOT_FRAMES="${GODOT_FRAMES:-1200}"

TMP_DIR=""
ISOLATED=""

cleanup() {
	if [[ -n "$TMP_DIR" ]]; then
		rm -rf "$TMP_DIR"
	fi
}

prepare_isolated() {
	if [[ -n "$ISOLATED" ]]; then
		return 0
	fi

	TMP_DIR="$(mktemp -d)"
	ISOLATED="$TMP_DIR/user_data"
	mkdir -p "$ISOLATED"
	trap cleanup EXIT

	local cache="$ROOT/.godot/global_script_class_cache.cfg"
	local stale=""
	if [[ -f "$cache" ]]; then
		stale="$(find "$ROOT" -name '*.gd' -newer "$cache" -print -quit)"
	fi

	if [[ ! -f "$cache" || -n "$stale" ]]; then
		echo "刷新 Godot 类缓存..." >&2
		local rc=0
		(
			export APPDATA="$ISOLATED"
			export XDG_DATA_HOME="$ISOLATED"
			"$GODOT_BIN" --headless --path "$ROOT" --import
		) > "$TMP_DIR/import.txt" 2>&1 || rc=$?
		if [[ $rc -ne 0 ]]; then
			echo "导入失败：$TMP_DIR/import.txt" >&2
			return 1
		fi
	fi
}

require_godot() {
	if [[ ! -f "$GODOT_BIN" ]]; then
		echo "找不到 Godot：$GODOT_BIN（用 GODOT_BIN 指定）" >&2
		return 2
	fi
}

run_godot_scene() {
	local scene="$1"
	local out="$2"
	shift 2
	local rc=0
	(
		export APPDATA="$ISOLATED"
		export XDG_DATA_HOME="$ISOLATED"
		"$GODOT_BIN" --headless --path "$ROOT" "$scene" --quit-after "$GODOT_FRAMES" -- "$@"
	) > "$out" 2>&1 || rc=$?
	return "$rc"
}

compile_check() {
	require_godot || return $?
	prepare_isolated || return 1

	local out="$TMP_DIR/compile.txt"
	local rc=0
	run_godot_scene "res://tools/compile_check/check_scene.tscn" "$out" || rc=$?

	if grep -Eq "SCRIPT ERROR: (Parse|Compile) Error|Failed to load script|Failed to instantiate an autoload" "$out"; then
		echo "编译检查失败：" >&2
		grep -E "SCRIPT ERROR: (Parse|Compile) Error|Failed to load script|Failed to instantiate an autoload|at: GDScript::reload" "$out" | head -80 >&2 || true
		return 1
	fi

	if ! grep -Eq "^CHECK_TOTAL " "$out"; then
		echo "编译检查失败：探针没有跑完（缺少 CHECK_TOTAL）" >&2
		tail -40 "$out" >&2 || true
		return 1
	fi

	if [[ $rc -ne 0 ]]; then
		echo "编译检查失败：Godot 退出码 $rc" >&2
		tail -40 "$out" >&2 || true
		return 1
	fi

	if grep -Eq "^CHECK_FAILED [1-9]" "$out"; then
		echo "编译检查失败：" >&2
		grep -E "^CHECK_FAIL|^CHECK_FAILED" "$out" | head -80 >&2 || true
		return 1
	fi

	grep -E "^CHECK_TOTAL|^CHECK_FAILED" "$out" | tail -2
}

scenario_check() {
	require_godot || return $?
	prepare_isolated || return 1

	local out="$TMP_DIR/scenario.txt"
	local rc=0
	run_godot_scene "res://tools/scenarios/run.tscn" "$out" "$@" || rc=$?

	grep -E "^SCENARIO .* (PASS|FAIL)" "$out" || true

	if ! grep -Eq "^SCENARIO_TOTAL " "$out"; then
		echo "情景测试失败：运行器没有跑完（缺少 SCENARIO_TOTAL）" >&2
		tail -60 "$out" >&2 || true
		return 1
	fi

	if grep -Eq "^SCENARIO_FAILED [1-9]" "$out"; then
		echo "情景测试失败：" >&2
		grep -E "^SCENARIO (ERROR|FAIL)|^  - " "$out" | head -80 >&2 || true
		return 1
	fi

	if [[ $rc -ne 0 ]]; then
		echo "情景测试失败：Godot 退出码 $rc" >&2
		tail -60 "$out" >&2 || true
		return 1
	fi

	grep -E "^SCENARIO_TOTAL|^SCENARIO_FAILED" "$out" | tail -2
}

lint_staged() {
	"$PYTHON_BIN" -X utf8 -I "$ROOT/tools/lint/runner.py" --root "$ROOT" --staged
	"$PYTHON_BIN" -X utf8 -I "$ROOT/tools/lint/index_meta.py" --root "$ROOT"
}

lint_all() {
	"$PYTHON_BIN" -X utf8 -I -m unittest discover -s "$ROOT/tools/lint/tests" -v
	"$PYTHON_BIN" -X utf8 -I "$ROOT/tools/lint/runner.py" --root "$ROOT" --all
	"$PYTHON_BIN" -X utf8 -I "$ROOT/tools/lint/index_meta.py" --root "$ROOT"
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
		lint_staged
		compile_check
		scenario_check
		;;
	--all)
		lint_all
		compile_check
		scenario_check
		;;
	--scenario)
		shift
		scenario_check "$@"
		;;
	--help|-h)
		echo "用法：tools/check.sh [--file <path>... | --staged | --all | --scenario <name>...]"
		;;
	*)
		echo "未知参数：$1" >&2
		exit 2
		;;
esac
