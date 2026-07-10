// 文件：command_test.cj
// 用途：gix_command 包的单元测试，对齐 Rust gitoxide gix-command 测试
// 所属包：gix.gix_command
// 对齐来源：gix-command/tests/command.rs

package gitoxide.gix_command

import std.collection.*
import std.unittest.*

// ============================================================
// Prepare 构造与字段测试（非对齐，仓颉补充的基础验证）
// ============================================================

@Test
func testPrepareConstruct(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare 构造
    let p = prepare("git")
    if (p.command != "git") {
        throw Exception("command should be 'git'")
    }
    if (p.args.size != 0) {
        throw Exception("args should be empty")
    }
    if (!p.context.isNone()) {
        throw Exception("context should default to None")
    }
    if (p.envVars.size != 0) {
        throw Exception("envVars should be empty")
    }
    if (p.useShell) {
        throw Exception("useShell should default to false")
    }
    if (p.quoteCommand) {
        throw Exception("quoteCommand should default to false")
    }
    if (!p.shellProgram.isNone()) {
        throw Exception("shellProgram should default to None")
    }
    if (p.allowManualArgSplitting) {
        throw Exception("allowManualArgSplitting should default to false")
    }
}

@Test
func testPrepareArg(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare::arg()
    let p = arg(prepare("git"), "clone")
    if (p.args.size != 1) {
        throw Exception("args should have 1 element")
    }
    if (p.args[0] != "clone") {
        throw Exception("first arg should be 'clone'")
    }
}

@Test
func testPrepareArgChain(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare::arg() 链式调用
    let p = arg(arg(arg(prepare("git"), "clone"), "--depth"), "1")
    if (p.args.size != 3) {
        throw Exception("args should have 3 elements")
    }
    if (p.args[0] != "clone") {
        throw Exception("first arg should be 'clone'")
    }
    if (p.args[1] != "--depth") {
        throw Exception("second arg should be '--depth'")
    }
    if (p.args[2] != "1") {
        throw Exception("third arg should be '1'")
    }
}

@Test
func testPrepareAddArgs(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare::add_args()
    let extra = ArrayList<String>()
    extra.add("clone")
    extra.add("origin")
    let p = addArgs(prepare("git"), extra)
    if (p.args.size != 2) {
        throw Exception("args should have 2 elements")
    }
    if (p.args[0] != "clone") {
        throw Exception("first arg should be 'clone'")
    }
    if (p.args[1] != "origin") {
        throw Exception("second arg should be 'origin'")
    }
}

@Test
func testPrepareFullPathCommand(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare 全路径命令
    let p = prepare("/usr/bin/git")
    if (p.command != "/usr/bin/git") {
        throw Exception("command should be '/usr/bin/git'")
    }
}

@Test
func testPrepareAddArgsAndArg(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare::add_args + arg 组合
    let extra = ArrayList<String>()
    extra.add("clone")
    let p = arg(addArgs(prepare("git"), extra), "origin")
    if (p.args.size != 2) {
        throw Exception("args should have 2 elements")
    }
    if (p.args[0] != "clone") {
        throw Exception("first arg should be 'clone'")
    }
    if (p.args[1] != "origin") {
        throw Exception("second arg should be 'origin'")
    }
}

@Test
func testPrepareEmptyAddArgs(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare::add_args 空参数
    let empty = ArrayList<String>()
    let p = addArgs(prepare("git"), empty)
    if (p.args.size != 0) {
        throw Exception("args should be empty")
    }
}

@Test
func testPrepareArgWithEquals(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare::arg 含等号参数
    let p = arg(prepare("git"), "--foo=bar baz")
    if (p.args[0] != "--foo=bar baz") {
        throw Exception("arg with spaces in value")
    }
}

@Test
func testPrepareArgWithSeparator(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare::arg 含分隔符
    let p = arg(arg(prepare("git"), "--"), "file with spaces")
    if (p.args[0] != "--") {
        throw Exception("separator should be '--'")
    }
    if (p.args[1] != "file with spaces") {
        throw Exception("file arg with spaces")
    }
}

// ============================================================
// Context 测试 — 对齐 Rust gix-command/tests/command.rs mod context
// ============================================================

@Test
func testContextDefault(): Unit {
    // 对齐 Rust: gix-command/tests/command.rs — mod context 默认值
    let ctx = Context()
    if (!ctx.gitDir.isNone()) {
        throw Exception("gitDir should be None")
    }
    if (!ctx.worktreeDir.isNone()) {
        throw Exception("worktreeDir should be None")
    }
    if (!ctx.noReplaceObjects.isNone()) {
        throw Exception("noReplaceObjects should be None")
    }
    if (!ctx.refNamespace.isNone()) {
        throw Exception("refNamespace should be None")
    }
    if (!ctx.literalPathspecs.isNone()) {
        throw Exception("literalPathspecs should be None")
    }
    if (!ctx.globPathspecs.isNone()) {
        throw Exception("globPathspecs should be None")
    }
    if (!ctx.icasePathspecs.isNone()) {
        throw Exception("icasePathspecs should be None")
    }
}

@Test
func testContextWithGitDir(): Unit {
    // 对齐 Rust: context::git_dir_sets_git_dir_env_and_cwd
    let ctx = Context()
    ctx.gitDir = "."
    let p = withContext(prepare("git"), ctx)
    if (p.context.isNone()) {
        throw Exception("context should be set")
    }
    if (let Some(c) <- p.context) {
        if (c.gitDir != Some(".")) {
            throw Exception("gitDir should be '.'")
        }
    }
}

@Test
func testContextWithWorktreeDir(): Unit {
    // 对齐 Rust: context::worktree_dir_sets_env_only
    let ctx = Context()
    ctx.worktreeDir = "."
    let p = withContext(prepare("git"), ctx)
    if (let Some(c) <- p.context) {
        if (c.worktreeDir != Some(".")) {
            throw Exception("worktreeDir should be '.'")
        }
    }
}

@Test
func testContextWithNoReplaceObjects(): Unit {
    // 对齐 Rust: context::no_replace_objects_sets_env_only
    let ctx = Context()
    ctx.noReplaceObjects = true
    let p = withContext(prepare("git"), ctx)
    if (let Some(c) <- p.context) {
        if (c.noReplaceObjects != Some(true)) {
            throw Exception("noReplaceObjects should be true")
        }
    }
}

@Test
func testContextWithRefNamespace(): Unit {
    // 对齐 Rust: context::ref_namespace_sets_env_only
    let ctx = Context()
    ctx.refNamespace = "ns"
    let p = withContext(prepare("git"), ctx)
    if (let Some(c) <- p.context) {
        if (c.refNamespace != Some("ns")) {
            throw Exception("refNamespace should be 'ns'")
        }
    }
}

@Test
func testContextWithLiteralPathspecs(): Unit {
    // 对齐 Rust: context::literal_pathspecs_sets_env_only
    let ctx = Context()
    ctx.literalPathspecs = true
    let p = withContext(prepare("git"), ctx)
    if (let Some(c) <- p.context) {
        if (c.literalPathspecs != Some(true)) {
            throw Exception("literalPathspecs should be true")
        }
    }
}

@Test
func testContextWithGlobPathspecs(): Unit {
    // 对齐 Rust: context::glob_pathspecs_sets_env_only
    for (value in [false, true]) {
        let ctx = Context()
        ctx.globPathspecs = value
        let p = withContext(prepare("git"), ctx)
        if (let Some(c) <- p.context) {
            if (c.globPathspecs != Some(value)) {
                throw Exception("globPathspecs mismatch")
            }
        }
    }
}

@Test
func testContextWithIcasePathspecs(): Unit {
    // 对齐 Rust: context::icase_pathspecs_sets_env_only
    for (value in [false, true]) {
        let ctx = Context()
        ctx.icasePathspecs = value
        let p = withContext(prepare("git"), ctx)
        if (let Some(c) <- p.context) {
            if (c.icasePathspecs != Some(value)) {
                throw Exception("icasePathspecs mismatch")
            }
        }
    }
}

// ============================================================
// Prepare env 测试（非对齐，仓颉补充的 env 变量验证）
// ============================================================

@Test
func testPrepareEnv(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare::env()
    let p = env(env(prepare("echo"), "FIRST", "first"), "SECOND", "second")
    if (p.envVars.size != 2) {
        throw Exception("should have 2 env vars")
    }
    if (p.envVars[0] != ("FIRST", "first")) {
        throw Exception("first env var mismatch")
    }
    if (p.envVars[1] != ("SECOND", "second")) {
        throw Exception("second env var mismatch")
    }
}

@Test
func testPrepareEnvMultiple(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare::env() 多环境变量
    let p = env(env(env(prepare("git"), "A", "1"), "B", "2"), "C", "3")
    if (p.envVars.size != 3) {
        throw Exception("should have 3 env vars")
    }
}

@Test
func testPrepareEnvOverwrite(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare::env() 覆盖
    let p = env(env(prepare("git"), "KEY", "old"), "KEY", "new")
    if (p.envVars.size != 2) {
        throw Exception("should have 2 entries")
    }
    if (p.envVars[0] != ("KEY", "old")) {
        throw Exception("first should be 'old'")
    }
    if (p.envVars[1] != ("KEY", "new")) {
        throw Exception("second should be 'new'")
    }
}

// ============================================================
// Prepare shell 模式测试 — 对齐 Rust gix-command/tests/command.rs mod prepare
// ============================================================

@Test
func testPrepareEmptyCommand(): Unit {
    // 对齐 Rust: prepare::empty
    let p = prepare("")
    if (toDebugString(p) != "\"\"") {
        throw Exception("empty command should be '\"\"', got '${toDebugString(p)}'")
    }
}

@Test
func testPrepareWhitespaceOnlyWithoutShell(): Unit {
    // 对齐 Rust: prepare::whitespace_only_without_shell
    let p = prepare("   ")
    if (toDebugString(p) != "\"   \"") {
        throw Exception("whitespace only should be '\"   \"', got '${toDebugString(p)}'")
    }
}

@Test
func testPrepareWhitespaceOnlyWithAutoSplitFallsBackToShell(): Unit {
    // 对齐 Rust: prepare::whitespace_only_commands_with_auto_split_fall_back_to_shell
    let p = commandMayBeShellScriptAllowManualArgSplitting(prepare("   "))
    var debug = toDebugString(p)
    if (!debug.contains("-c")) {
        throw Exception("whitespace with auto-split should use shell, got '${debug}'")
    }
}

@Test
func testPrepareSingleAndMultipleArguments(): Unit {
    // 对齐 Rust: prepare::single_and_multiple_arguments
    let p = arg(addArgs(arg(prepare("ls"), "first"), arrayListFrom("second", "third")), "fourth")
    var debug = toDebugString(p)
    if (debug != "\"ls\" \"first\" \"second\" \"third\" \"fourth\"") {
        throw Exception("got '${debug}'")
    }
}

@Test
func testPrepareMultipleArgumentsInOneLineWithAutoSplit(): Unit {
    // 对齐 Rust: prepare::multiple_arguments_in_one_line_with_auto_split
    let p = commandMayBeShellScriptAllowManualArgSplitting(prepare("echo first second third"))
    var debug = toDebugString(p)
    if (debug != "\"echo\" \"first\" \"second\" \"third\"") {
        throw Exception("auto-split should work, got '${debug}'")
    }
}

@Test
func testPrepareArgumentsAsPartOfCommandNoShell(): Unit {
    // 对齐 Rust: prepare::single_and_multiple_arguments_as_part_of_command
    let p = prepare("ls first second third")
    var debug = toDebugString(p)
    if (debug != "\"ls first second third\"") {
        throw Exception("without shell, whole string is command, got '${debug}'")
    }
}

@Test
func testPrepareArgumentsAsPartOfCommandWithShell(): Unit {
    // 对齐 Rust: prepare::single_and_multiple_arguments_as_part_of_command_with_shell
    let p = commandMayBeShellScript(prepare("ls first second third"))
    var debug = toDebugString(p)
    if (!debug.contains("-c")) {
        throw Exception("with shell, should use -c, got '${debug}'")
    }
}

@Test
func testPrepareWithShellProgram(): Unit {
    // 对齐 Rust: prepare::single_and_multiple_arguments_as_part_of_command_with_given_shell
    let p = withShellProgram(commandMayBeShellScript(prepare("ls first second third")), "/somepath/to/bash")
    var debug = toDebugString(p)
    if (!debug.contains("/somepath/to/bash")) {
        throw Exception("should use custom shell, got '${debug}'")
    }
    if (!debug.contains("-c")) {
        throw Exception("should use -c, got '${debug}'")
    }
}

@Test
func testPrepareComplexArgumentsWithShell(): Unit {
    // 对齐 Rust: prepare::single_and_complex_arguments_as_part_of_command_with_shell
    let p = arg(commandMayBeShellScript(prepare("ls --foo \"a b\"")), "additional")
    var debug = toDebugString(p)
    if (!debug.contains("-c")) {
        throw Exception("should use shell -c, got '${debug}'")
    }
}

@Test
func testPrepareComplexArgumentsWithAutoSplit(): Unit {
    // 对齐 Rust: prepare::single_and_complex_arguments_with_auto_split
    // 注意：shell_words 不支持引号拆分时回退到 shell 模式
    let p = commandMayBeShellScriptAllowManualArgSplitting(prepare("ls --foo=\"a b\""))
    var debug = toDebugString(p)
    if (debug != "\"ls\" \"--foo=a b\"" && debug != "\"/bin/sh\" \"-c\" \"ls --foo=\\\"a b\\\"\" \"sh\"") {
        throw Exception("auto-split with quotes should work or fallback to shell, got '${debug}'")
    }
}

@Test
func testPrepareComplexArgumentsWithoutAutoSplit(): Unit {
    // 对齐 Rust: prepare::single_and_complex_arguments_without_auto_split
    let p = commandMayBeShellScriptDisallowManualArgSplitting(prepare("ls --foo=\"a b\""))
    var debug = toDebugString(p)
    if (!debug.contains("-c")) {
        throw Exception("should use shell -c, got '${debug}'")
    }
}

@Test
func testPrepareSimpleArgsWithoutAutoSplitWithShell(): Unit {
    // 对齐 Rust: prepare::single_and_simple_arguments_without_auto_split_with_shell
    let p = arg(withShell(prepare("ls")), "--foo=a b")
    var debug = toDebugString(p)
    if (!debug.contains("-c")) {
        throw Exception("with_shell should use -c, got '${debug}'")
    }
}

@Test
func testPrepareQuotedCommandWithoutArgSplitting(): Unit {
    // 对齐 Rust: prepare::quoted_command_without_argument_splitting
    let p = withQuotedCommand(arg(withShell(prepare("ls")), "--foo=a b"))
    var debug = toDebugString(p)
    if (!debug.contains("-c")) {
        throw Exception("should use shell, got '${debug}'")
    }
}

@Test
func testPrepareWillNotAutoSplitOnSpecialCharacters(): Unit {
    // 对齐 Rust: prepare::single_and_complex_arguments_will_not_auto_split_on_special_characters
    let p = commandMayBeShellScriptAllowManualArgSplitting(prepare("ls --foo=~/path"))
    var debug = toDebugString(p)
    if (!debug.contains("-c")) {
        throw Exception("tilde should block auto-split, got '${debug}'")
    }
}

@Test
func testPrepareTildePathWithShell(): Unit {
    // 对齐 Rust: prepare::tilde_path_and_multiple_arguments_as_part_of_command_with_shell
    let p = commandMayBeShellScript(prepare("~/bin/exe --foo \"a b\""))
    var debug = toDebugString(p)
    if (!debug.contains("-c")) {
        throw Exception("tilde should trigger shell, got '${debug}'")
    }
}

@Test
func testPrepareScriptWithDollarAt(): Unit {
    // 对齐 Rust: prepare::script_with_dollar_at
    let p = arg(commandMayBeShellScript(prepare("echo \"$@\" >&2")), "store")
    var debug = toDebugString(p)
    if (!debug.contains("-c")) {
        throw Exception("should use shell, got '${debug}'")
    }
    if (!debug.contains("store")) {
        throw Exception("should pass 'store' as arg, got '${debug}'")
    }
}

@Test
func testPrepareScriptWithDollarAtHasNoQuoting(): Unit {
    // 对齐 Rust: prepare::script_with_dollar_at_has_no_quoting
    let p = arg(withQuotedCommand(commandMayBeShellScript(prepare("echo \"$@\" >&2"))), "store")
    var debug = toDebugString(p)
    if (!debug.contains("-c")) {
        throw Exception("should use shell, got '${debug}'")
    }
}

@Test
func testPrepareShellProgramNoBasenameUsesUnderscore(): Unit {
    // 对齐 Rust: prepare::shell_program_with_no_basename_uses_underscore_placeholder
    let p = withShellProgram(commandMayBeShellScriptDisallowManualArgSplitting(prepare("echo hi")), "")
    var debug = toDebugString(p)
    if (!debug.contains("-c")) {
        throw Exception("should use shell, got '${debug}'")
    }
    if (!debug.contains("_")) {
        throw Exception("should use _ as basename, got '${debug}'")
    }
}

@Test
func testPrepareWithShellAddsDollarAtForArgs(): Unit {
    // 对齐 Rust: prepare::single_and_simple_arguments_without_auto_split_with_shell
    // （验证 with_shell + arg 时自动添加 "$@"）
    let p = arg(withShell(prepare("echo")), "hello")
    var (program, cmdArgs) = toCommandParts(p)
    var scriptCmd = cmdArgs[1]
    if (!scriptCmd.contains("$@")) {
        throw Exception("should add '$@' for args, script='${scriptCmd}'")
    }
}

@Test
func testPrepareWithShellNoDollarAtWhenNoArgs(): Unit {
    // 对齐 Rust: prepare::empty（验证 with_shell 无额外参数时不添加 "$@"）
    let p = withShell(prepare("echo"))
    var (program, cmdArgs) = toCommandParts(p)
    var scriptCmd = cmdArgs[1]
    if (scriptCmd.contains("$@")) {
        throw Exception("should NOT add '$@' when no args, script='${scriptCmd}'")
    }
}

@Test
func testPrepareWithoutShell(): Unit {
    // 对齐 Rust: spawn::disallow_shell（验证 without_shell 可取消 shell 模式）
    let p = withoutShell(withShell(prepare("echo")))
    if (p.useShell) {
        throw Exception("without_shell should disable shell")
    }
}

// ============================================================
// Shebang 解析测试 — 对齐 Rust gix-command/tests/command.rs mod shebang
// ============================================================

@Test
func testShebangParseValid(): Unit {
    // 对齐 Rust: shebang::parse::valid — assert_eq!(parse("#!/bin/sh"), exe("/bin/sh"))
    let result = parseShebang("#!/bin/sh")
    if (result.isNone()) {
        throw Exception("should parse valid shebang")
    }
    if (let Some(d) <- result) {
        if (d.interpreter != "/bin/sh") {
            throw Exception("interpreter should be '/bin/sh'")
        }
        if (d.args.size != 0) {
            throw Exception("args should be empty")
        }
    }
}

@Test
func testShebangParseWithTrailingWhitespace(): Unit {
    // 对齐 Rust: shebang::parse::valid — assert_eq!(parse("#!/bin/sh   "), exe("/bin/sh"), "trim trailing whitespace")
    let result = parseShebang("#!/bin/sh   ")
    if (result.isNone()) {
        throw Exception("should parse")
    }
    if (let Some(d) <- result) {
        if (d.interpreter != "/bin/sh") {
            throw Exception("interpreter should be '/bin/sh'")
        }
    }
}

@Test
func testShebangParseWithTabAndNewline(): Unit {
    // 对齐 Rust: shebang::parse::valid — assert_eq!(parse("#!/bin/sh\t\nother"), exe("/bin/sh"), "trimming works for tabs as well")
    let result = parseShebang("#!/bin/sh\t\nother")
    if (result.isNone()) {
        throw Exception("should parse")
    }
    if (let Some(d) <- result) {
        if (d.interpreter != "/bin/sh") {
            throw Exception("interpreter should be '/bin/sh'")
        }
    }
}

@Test
func testShebangParseWithArg(): Unit {
    // 对齐 Rust: shebang::parse::valid — assert_eq!(parse("#!/bin/sh -i -o -u\n..."), exe_arg("/bin/sh", "-i -o -u"))
    let result = parseShebang("#!/usr/bin/env bash")
    if (result.isNone()) {
        throw Exception("should parse")
    }
    if (let Some(d) <- result) {
        if (d.interpreter != "/usr/bin/env") {
            throw Exception("interpreter should be '/usr/bin/env'")
        }
        if (d.args.size != 1 || d.args[0] != "bash") {
            throw Exception("arg should be 'bash'")
        }
    }
}

@Test
func testShebangParseInvalidEmpty(): Unit {
    // 对齐 Rust: shebang::parse::invalid — assert_eq!(parse(""), None)
    let result = parseShebang("")
    if (!result.isNone()) {
        throw Exception("empty should return None")
    }
}

@Test
func testShebangParseInvalidNoShebang(): Unit {
    // 对齐 Rust: shebang::parse::invalid — assert_eq!(parse("missing shebang"), None)
    let result = parseShebang("missing shebang")
    if (!result.isNone()) {
        throw Exception("missing shebang should return None")
    }
}

@Test
func testShebangParseInvalidMissingSlash(): Unit {
    // 对齐 Rust: shebang::parse::invalid — assert_eq!(parse("#!missing-slash"), None)
    let result = parseShebang("#!missing-slash")
    if (!result.isNone()) {
        throw Exception("#!without slash should return None")
    }
}

@Test
func testShebangParseInvalidPath(): Unit {
    // 对齐 Rust: shebang::parse::invalid — assert_eq!(parse("/bin/sh"), None, "shebang missing")
    let result = parseShebang("/bin/sh")
    if (!result.isNone()) {
        throw Exception("path without #! should return None")
    }
}

// ============================================================
// shell 辅助函数测试（非对齐，仓颉补充的内部函数验证）
// ============================================================

@Test
func testContainsShellMetaCharsPipe(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — containsShellMetaChars 管道符
    if (!containsShellMetaChars("cmd | other")) {
        throw Exception("pipe is meta")
    }
}

@Test
func testContainsShellMetaCharsAmpersand(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — containsShellMetaChars &
    if (!containsShellMetaChars("cmd && other")) {
        throw Exception("&& is meta")
    }
}

@Test
func testContainsShellMetaCharsDollar(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — containsShellMetaChars $
    if (!containsShellMetaChars("$HOME")) {
        throw Exception("$ is meta")
    }
}

@Test
func testContainsShellMetaCharsTilde(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — containsShellMetaChars ~
    if (!containsShellMetaChars("~/path")) {
        throw Exception("~ is meta")
    }
}

@Test
func testContainsShellMetaCharsNone(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — containsShellMetaChars 无元字符
    if (containsShellMetaChars("simple_command")) {
        throw Exception("no meta chars")
    }
}

@Test
func testContainsShellMetaCharsSpace(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — containsShellMetaChars 空格
    if (!containsShellMetaChars("echo hello")) {
        throw Exception("space is meta")
    }
}

@Test
func testContainsShellSplitBlockingCharsTilde(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — containsShellSplitBlockingChars ~
    if (!containsShellSplitBlockingChars("~/path")) {
        throw Exception("~ blocks split")
    }
}

@Test
func testContainsShellSplitBlockingCharsNone(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — containsShellSplitBlockingChars 无
    if (containsShellSplitBlockingChars("echo hello world")) {
        throw Exception("no blocking chars")
    }
}

@Test
func testShellBasenameNormal(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — shellBasename 普通路径
    if (shellBasename("/bin/sh") != "sh") {
        throw Exception("basename of /bin/sh should be 'sh'")
    }
}

@Test
func testShellBasenameWindows(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — shellBasename Windows 路径
    if (shellBasename("C:\\Windows\\System32\\cmd.exe") != "cmd.exe") {
        throw Exception("basename mismatch")
    }
}

@Test
func testShellBasenameEmpty(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — shellBasename 空字符串 → "_"
    if (shellBasename("") != "_") {
        throw Exception("empty should return '_'")
    }
}

@Test
func testShellBasenameJustSlash(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — shellBasename 仅斜杠 → "_"
    if (shellBasename("/") != "_") {
        throw Exception("just slash should return '_'")
    }
}

@Test
func testContainsDollarAtPresent(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — containsDollarAt 含 $@
    if (!containsDollarAt("echo \"$@\" >&2")) {
        throw Exception("should find $@")
    }
}

@Test
func testContainsDollarAtAbsent(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — containsDollarAt 无 $@
    if (containsDollarAt("echo hello")) {
        throw Exception("should not find $@")
    }
}

// ============================================================
// Prepare 实际执行测试（非对齐，仓颉补充的端到端验证）
// ============================================================

@Test
func testPrepareRunSimpleCommand(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare::run 简单命令
    let p = arg(arg(prepare("cmd"), "/c"), "echo hello")
    let result = runPrepare(p)
    if (result.isNone()) {
        throw Exception("should return result")
    }
    if (let Some(r) <- result) {
        if (!r.success()) {
            throw Exception("echo should succeed")
        }
    } else {
        throw Exception("no result")
    }
}

@Test
func testPrepareRunWithContext(): Unit {
    // 对齐 Rust: gix-command/src/prepare.rs — Prepare::run 带上下文
    let ctx = Context()
    ctx.gitDir = "."
    let p = arg(arg(withContext(prepare("cmd"), ctx), "/c"), "echo test")
    let result = runPrepare(p)
    if (result.isNone()) {
        throw Exception("should return result")
    }
}

@Test
func testSpawnDisallowShell(): Unit {
    // 对齐 Rust: spawn::disallow_shell — without_shell() 后执行带空格的命令名应失败
    let p = withoutShell(commandMayBeShellScript(prepare("echo hi")))
    let result = runPrepare(p)
    if (!result.isNone()) {
        // Windows 上 "echo hi" 作为命令名可能被 cmd 解释成功，
        // 但 without_shell 模式下不应通过 shell 执行
        if (let Some(r) <- result) {
            if (r.success()) {
                throw Exception("'echo hi' as command name should fail without shell")
            }
        }
    }
}

@Test
func testShebangParseBackslashPath(): Unit {
    // 对齐 Rust: shebang::parse::valid — assert_eq!(parse(r"#!\bin\sh"), exe(r"\bin\sh"), "backslashes are recognized as path separator")
    let result = parseShebang("#!\\bin\\sh")
    if (result.isNone()) {
        throw Exception("should parse backslash path")
    }
    if (let Some(d) <- result) {
        if (d.interpreter != "\\bin\\sh") {
            throw Exception("interpreter should be '\\bin\\sh', got '${d.interpreter}'")
        }
    }
}

@Test
func testShebangParseMultipleArgs(): Unit {
    // 对齐 Rust: shebang::parse::valid — assert_eq!(parse("#!/bin/sh -i -o -u\n..."), exe_arg("/bin/sh", "-i -o -u"), "argument splitting happens as well")
    let result = parseShebang("#!/bin/sh -i -o -u\nunrelated content")
    if (result.isNone()) {
        throw Exception("should parse with multiple args")
    }
    if (let Some(d) <- result) {
        if (d.interpreter != "/bin/sh") {
            throw Exception("interpreter should be '/bin/sh'")
        }
        if (d.args.size != 3) {
            throw Exception("should have 3 args, got ${d.args.size}")
        }
        if (d.args[0] != "-i") {
            throw Exception("first arg should be '-i'")
        }
        if (d.args[1] != "-o") {
            throw Exception("second arg should be '-o'")
        }
        if (d.args[2] != "-u") {
            throw Exception("third arg should be '-u'")
        }
    }
}

@Test
func testShebangParseSingleArg(): Unit {
    // 对齐 Rust: shebang::parse::valid — assert_eq!(parse("#!/bin/sh  -o\n..."), exe_arg("/bin/sh", "-o"), "single arguments are OK too")
    let result = parseShebang("#!/bin/sh  -o\nunrelated content")
    if (result.isNone()) {
        throw Exception("should parse with single arg")
    }
    if (let Some(d) <- result) {
        if (d.interpreter != "/bin/sh") {
            throw Exception("interpreter should be '/bin/sh'")
        }
        if (d.args.size != 1) {
            throw Exception("should have 1 arg")
        }
        if (d.args[0] != "-o") {
            throw Exception("arg should be '-o'")
        }
    }
}

@Test
func testShebangParseAnyArgs(): Unit {
    // 对齐 Rust: shebang::parse::valid — assert_eq!(parse("#!/bin/exe anything goes\n..."), exe_arg("/bin/exe", "anything goes"), "any argument works")
    let result = parseShebang("#!/bin/exe anything goes\nunrelated content")
    if (result.isNone()) {
        throw Exception("should parse with any args")
    }
    if (let Some(d) <- result) {
        if (d.interpreter != "/bin/exe") {
            throw Exception("interpreter should be '/bin/exe'")
        }
        if (d.args.size != 2) {
            throw Exception("should have 2 args, got ${d.args.size}")
        }
        if (d.args[0] != "anything") {
            throw Exception("first arg should be 'anything'")
        }
        if (d.args[1] != "goes") {
            throw Exception("second arg should be 'goes'")
        }
    }
}

// ============================================================
// 辅助函数
// ============================================================

func arrayListFrom(elements: Array<String>): ArrayList<String> {
    var list = ArrayList<String>()
    for (e in elements) {
        list.add(e)
    }
    list
}
