// 文件：lib.cj
// 用途：外部命令执行封装，用于调用 Git 等外部进程
// 所属包：gix.gix_command
// 关键类型：Prepare, Context, ShebangData
// 对齐来源：gix-command/src/lib.rs

package gitoxide.gix_command

import std.collection.*
import std.process.*
import shell_words.*
import gitoxide.gix_quote

// 命令执行的上下文信息，用于设置 Git 相关环境变量
// 对齐 Rust: gix_command::Context
public class Context {
    public var gitDir: ?String
    public var worktreeDir: ?String
    public var noReplaceObjects: ?Bool
    public var refNamespace: ?String
    public var literalPathspecs: ?Bool
    public var globPathspecs: ?Bool
    public var icasePathspecs: ?Bool

    public init() {
        this.gitDir = None
        this.worktreeDir = None
        this.noReplaceObjects = None
        this.refNamespace = None
        this.literalPathspecs = None
        this.globPathspecs = None
        this.icasePathspecs = None
    }
}

// Shebang 解析结果
// 对齐 Rust: gix_command::shebang::Data
public class ShebangData {
    public var interpreter: String
    public var args: ArrayList<String>

    public init(interpreter: String) {
        this.interpreter = interpreter
        this.args = ArrayList<String>()
    }

    public init(interpreter: String, args: ArrayList<String>) {
        this.interpreter = interpreter
        this.args = args
    }
}

// 对齐 Rust: gix_command::Prepare
// 命令构建器，支持 shell 执行、参数拆分、命令引用等
public class Prepare {
    // 要执行的命令
    public var command: String
    // 上下文信息
    public var context: ?Context
    // 参数列表
    public var args: ArrayList<String>
    // 环境变量
    public var envVars: ArrayList<(String, String)>
    // 是否使用 shell 执行
    public var useShell: Bool
    // 是否引用命令（单引号包裹）
    public var quoteCommand: Bool
    // 自定义 shell 程序路径
    public var shellProgram: ?String
    // 是否允许手动参数拆分
    public var allowManualArgSplitting: Bool

    public init(command: String) {
        this.command = command
        this.context = None
        this.args = ArrayList<String>()
        this.envVars = ArrayList<(String, String)>()
        this.useShell = false
        this.quoteCommand = false
        this.shellProgram = None
        this.allowManualArgSplitting = false
    }
}

// ====== Prepare Builder 方法 ======

// 对齐 Rust: Prepare::command_may_be_shell_script()
// 检测命令是否可能为 shell 脚本（包含特殊字符）
public func commandMayBeShellScript(p: Prepare): Prepare {
    p.useShell = containsShellMetaChars(p.command)
    p
}

// 对齐 Rust: Prepare::with_shell()
// 无条件使用 shell 执行
public func withShell(p: Prepare): Prepare {
    p.useShell = true
    p.allowManualArgSplitting = false
    p
}

// 对齐 Rust: Prepare::without_shell()
// 禁用 shell 执行
public func withoutShell(p: Prepare): Prepare {
    p.useShell = false
    p
}

// 对齐 Rust: Prepare::with_quoted_command()
// 引用命令路径（单引号包裹）
public func withQuotedCommand(p: Prepare): Prepare {
    p.quoteCommand = true
    p
}

// 对齐 Rust: Prepare::with_shell_program()
// 设置自定义 shell 程序
public func withShellProgram(p: Prepare, program: String): Prepare {
    p.shellProgram = Some(program)
    p
}

// 对齐 Rust: Prepare::with_context()
public func withContext(p: Prepare, ctx: Context): Prepare {
    p.context = Some(ctx)
    p
}

// 对齐 Rust: Prepare::command_may_be_shell_script_allow_manual_argument_splitting()
public func commandMayBeShellScriptAllowManualArgSplitting(p: Prepare): Prepare {
    p.allowManualArgSplitting = true
    commandMayBeShellScript(p)
}

// 对齐 Rust: Prepare::command_may_be_shell_script_disallow_manual_argument_splitting()
public func commandMayBeShellScriptDisallowManualArgSplitting(p: Prepare): Prepare {
    p.allowManualArgSplitting = false
    commandMayBeShellScript(p)
}

// 对齐 Rust: Prepare::arg()
public func arg(p: Prepare, a: String): Prepare {
    p.args.add(a)
    p
}

// 对齐 Rust: Prepare::args()
public func addArgs(p: Prepare, a: ArrayList<String>): Prepare {
    for (s in a) {
        p.args.add(s)
    }
    p
}

// 对齐 Rust: Prepare::env()
public func env(p: Prepare, key: String, value: String): Prepare {
    p.envVars.add((key, value))
    p
}

// ====== Prepare 最终化方法 ======

// 对齐 Rust: From<Prepare> for std::process::Command
// 将 Prepare 转换为可执行的命令参数列表
// 返回 (program, arguments) 元组
public func toCommandParts(p: Prepare): (String, Array<String>) {
    if (p.useShell) {
        var splitArgs: ?Array<String> = None
        if (p.allowManualArgSplitting) {
            if (!containsShellSplitBlockingChars(p.command)) {
                var splitResult = p.command.shellSplit()
                if (let Ok(parts) <- splitResult) {
                    if (parts.size > 0) {
                        splitArgs = Some(parts)
                    }
                }
            }
        }
        if (let Some(parts) <- splitArgs) {
            var program = parts[0]
            var cmdArgs = ArrayList<String>()
            for (i in 1..parts.size) {
                cmdArgs.add(parts[i])
            }
            for (a in p.args) {
                cmdArgs.add(a)
            }
            return (program, cmdArgs.toArray())
        } else {
            var shell = "/bin/sh"
            if (let Some(sp) <- p.shellProgram) {
                shell = sp
            }
            var scriptCmd = p.command
            if (!p.args.isEmpty()) {
                if (!containsDollarAt(scriptCmd)) {
                    if (p.quoteCommand) {
                        scriptCmd = gix_quote.singleString(scriptCmd)
                    }
                    scriptCmd = scriptCmd + " \"$@\""
                }
            }
            var arg0 = shellBasename(shell)
            var cmdArgs = ArrayList<String>()
            cmdArgs.add("-c")
            cmdArgs.add(scriptCmd)
            cmdArgs.add(arg0)
            for (a in p.args) {
                cmdArgs.add(a)
            }
            return (shell, cmdArgs.toArray())
        }
    } else {
        var program = p.command
        var cmdArgs = ArrayList<String>()
        for (a in p.args) {
            cmdArgs.add(a)
        }
        return (program, cmdArgs.toArray())
    }
}

// 对齐 Rust: Prepare::spawn()
// 执行命令并返回结果
public func runPrepare(p: Prepare): ?CommandResult {
    try {
        var (program, cmdArgs) = toCommandParts(p)
        var envMap = buildEnvMap(p)
        var envOpt: ?Map<String, String> = if (envMap.size > 0) {
            Some(envMap)
        } else {
            None
        }
        var result = executeWithOutput(program, cmdArgs, environment: envOpt)
        var stdoutStr = String.fromUtf8(result[1])
        Some(CommandResult(result[0], stdoutStr))
    } catch (_: Exception) {
        None
    }
}

// 对齐 Rust: std::process::Command 的 Debug 格式化
// 返回类似 `"program" "arg1" "arg2"` 的字符串
public func toDebugString(p: Prepare): String {
    var (program, cmdArgs) = toCommandParts(p)
    var parts = ArrayList<String>()
    parts.add(program)
    for (a in cmdArgs) {
        parts.add(a)
    }
    quoted(parts)
}

// ====== 辅助函数 ======

// 检测字符串是否包含 shell 元字符
// 对齐 Rust: command_may_be_shell_script() 中的 find_byteset
func containsShellMetaChars(s: String): Bool {
    // | & ; < > ( ) $ ` \ " ' 空格 \t \n * ? [ # ~ = %
    var i: Int64 = 0
    while (i < s.size) {
        var b = s[i]
        if (b == 124 || b == 38 || b == 59 || b == 60 || b == 62 || // | & ; < >
            b == 40 || b == 41 || b == 36 || b == 96 || // ( ) $ `
            b == 92 ||
            b == 34 || b == 39 || // \ " '
                b == 32 || b == 9 || b == 10 || // 空格 \t \n
                b == 42 || b == 63 || b == 91 || // * ? [
                b == 35 || b == 126 ||
            b == 61 || b == 37) { // # ~ = %
            return true
        }
        i += 1
    }
    false
}

// 检测字符串是否包含阻止手动参数拆分的字符
// 对齐 Rust: From<Prepare> for Command 中 find_byteset(b"\\|&;<>()$`\n*?[#~%")
public func containsShellSplitBlockingChars(s: String): Bool {
    var i: Int64 = 0
    while (i < s.size) {
        var b = s[i]
        if (b == 92 || b == 124 || b == 38 || b == 59 || b == 60 || // \ | & ; <
            b == 62 || b == 40 || b == 41 || b == 36 || b == 96 || // > ( ) $ `
            b == 10 || // \n
                b == 42 || b == 63 || b == 91 || // * ? [
                b == 35 || b == 126 || b == 61 || b == 37) { // # ~ = %
            return true
        }
        i += 1
    }
    false
}

// 检测命令字符串是否包含 "$@"
func containsDollarAt(s: String): Bool {
    var i: Int64 = 0
    while (i < s.size - 1) {
        if (s[i] == 36 && s[i + 1] == 64) { // $@
            return true
        }
        i += 1
    }
    false
}

// 获取 shell 路径的 basename（用作 $0）
func shellBasename(shell: String): String {
    var lastSlash: Int64 = -1
    var i: Int64 = 0
    while (i < shell.size) {
        if (shell[i] == 47 || shell[i] == 92) { // / or \
            lastSlash = i
        }
        i += 1
    }
    if (lastSlash < 0 || lastSlash >= shell.size - 1) {
        return "_"
    }
    shell[lastSlash + 1..]
}

// 将参数列表格式化为 Debug 字符串（双引号包裹每个参数，空格分隔）
// 对齐 Rust: std::process::Command 的 Debug 格式化
func quoted(parts: ArrayList<String>): String {
    var sb = StringBuilder()
    var first = true
    for (part in parts) {
        if (!first) {
            sb.append(" ")
        }
        sb.append("\"")
        sb.append(escapeForDebug(part))
        sb.append("\"")
        first = false
    }
    sb.toString()
}

// 对齐 Rust: std::process::Command Debug 格式化中的转义
// 双引号内的 \ 和 " 需要转义
func escapeForDebug(s: String): String {
    var sb = StringBuilder()
    var i: Int64 = 0
    while (i < s.size) {
        var b = s[i]
        if (b == 92) { // \
            sb.append("\\\\")
        } else if (b == 34) { // "
            sb.append("\\\"")
        } else {
            sb.append(s[i..i + 1])
        }
        i += 1
    }
    sb.toString()
}

// 构建环境变量 Map
func buildEnvMap(p: Prepare): HashMap<String, String> {
    let map = HashMap<String, String>()
    if (let Some(ctx) <- p.context) {
        if (let Some(gd) <- ctx.gitDir) {
            map.add("GIT_DIR", gd)
        }
        if (let Some(wd) <- ctx.worktreeDir) {
            map.add("GIT_WORK_TREE", wd)
        }
        if (let Some(val) <- ctx.noReplaceObjects) {
            map.add("GIT_NO_REPLACE_OBJECTS", if (val) {
                "1"
            } else {
                "0"
            })
        }
        if (let Some(rn) <- ctx.refNamespace) {
            map.add("GIT_NAMESPACE", rn)
        }
        if (let Some(val) <- ctx.literalPathspecs) {
            map.add("GIT_LITERAL_PATHSPECS", if (val) {
                "1"
            } else {
                "0"
            })
        }
        if (let Some(val) <- ctx.globPathspecs) {
            map.add("GIT_GLOB_PATHSPECS", if (val) {
                "1"
            } else {
                "0"
            })
        }
        if (let Some(val) <- ctx.icasePathspecs) {
            map.add("GIT_ICASE_PATHSPECS", if (val) {
                "1"
            } else {
                "0"
            })
        }
    }
    for ((k, v) in p.envVars) {
        map.add(k, v)
    }
    map
}

// 命令执行结果
public class CommandResult {
    public var exitCode: Int64
    public var stdout: String

    public init(exitCode: Int64, stdout: String) {
        this.exitCode = exitCode
        this.stdout = stdout
    }

    public func success(): Bool {
        exitCode == 0
    }
}

// ====== 顶层便捷函数 ======

// 对齐 Rust: gix_command::prepare()
public func prepare(command: String): Prepare {
    Prepare(command)
}

// Shebang 解析
// 对齐 Rust: gix_command::shebang::parse()
public func parseShebang(input: String): ?ShebangData {
    if (input.size < 2 || input[0] != 35 || input[1] != 33) { // #!
        return None
    }
    var content = input[2..]
    // 去掉前导空白
    while (content.size > 0 && (content[0] == 32 || content[0] == 9)) {
        content = content[1..]
    }
    if (content.isEmpty()) {
        return None
    }
    // 找到第一个空白或换行
    var end: Int64 = content.size
    var i: Int64 = 0
    while (i < content.size) {
        if (content[i] == 32 || content[i] == 9 || content[i] == 10) {
            end = i
            break
        }
        i += 1
    }
    var interpreter = content[0..end]
    if (interpreter.size == 0 || (interpreter[0] != 47 && interpreter[0] != 92)) { // 必须以 / 或 \ 开头
        return None
    }
    var rest = if (end < content.size) {
        content[end..]
    } else {
        ""
    }
    // 解析 shebang 的额外参数
    var shebangArgs = ArrayList<String>()
    if (!rest.isEmpty()) {
        while (rest.size > 0 && (rest[0] == 32 || rest[0] == 9)) {
            rest = rest[1..]
        }
        if (!rest.isEmpty() && rest[0] != 10) {
            var argEnd: Int64 = rest.size
            var j: Int64 = 0
            while (j < rest.size) {
                if (rest[j] == 10) {
                    argEnd = j
                    break
                }
                j += 1
            }
            var argStr = rest[0..argEnd]
            // 使用 shell_words::split 拆分参数
            var splitResult = argStr.shellSplit()
            if (let Ok(parts) <- splitResult) {
                for (part in parts) {
                    shebangArgs.add(part)
                }
            }
        }
    }
    Some(ShebangData(interpreter, shebangArgs))
}

// 对齐 Rust: gix_command::extract_interpreter()
public func extractInterpreter(path: String): ?ShebangData {
    try {
        var content = readFileContent(path)
        if (content.size < 2) {
            return None
        }
        if (content[0] != 35 || content[1] != 33) { // #!
            return None
        }
        parseShebang(content)
    } catch (_: Exception) {
        None
    }
}

// 读取文件前 256 字节为字符串
func readFileContent(path: String): String {
    try {
        var result = executeWithOutput("cmd", ["/c", "type", path])
        var (_, stdout, _) = result
        String.fromUtf8(stdout)
    } catch (_: Exception) {
        ""
    }
}
