// 文件：lib.cj
// 用途：用户交互提示抽象，定义提示响应类型、提示器接口和选项配置
// 所属包：gix.gix_prompt
// 关键类型：PromptResponse, Prompter, Mode, Options, PromptError
// 关键函数：ask, askWithEnvironment

package gitoxide.gix_prompt

import std.collection.*
import std.process.*
import std.env.*

// 提示响应，表示用户对提示的回复
public enum PromptResponse <: Equatable<PromptResponse> {
    | Yes // 用户确认（是）
    | No // 用户否认（否）
    | Value(String) // 用户输入的文本值

    public operator func ==(that: PromptResponse): Bool {
        match (this) {
            case Yes => match (that) {
                case Yes => true;
                case _ => false
            }
            case No => match (that) {
                case No => true;
                case _ => false
            }
            case Value(v1) => match (that) {
                case Value(v2) => v1 == v2;
                case _ => false
            }
        }
    }
}

// 提示器接口，用于与用户交互获取输入
public interface Prompter {
    // 显示消息提示并等待用户回复
    // 参数 message: 提示消息内容
    // 返回值: 用户的响应，取消或失败返回 None
    func prompt(message: String): ?PromptResponse

    // 提示用户输入密码（输入应被隐藏）
    // 参数 message: 提示消息内容
    // 返回值: 用户输入的密码，取消或失败返回 None
    func promptPassword(message: String): ?String
}

// 提示方式
// 对齐 Rust: gix_prompt::Mode
public enum Mode {
    | Visible
    | Hidden
    | Disable

    public operator func ==(that: Mode): Bool {
        match (this) {
            case Visible => match (that) {
                case Visible => true;
                case _ => false
            }
            case Hidden => match (that) {
                case Hidden => true;
                case _ => false
            }
            case Disable => match (that) {
                case Disable => true;
                case _ => false
            }
        }
    }
    public operator func !=(that: Mode): Bool {
        !(this == that)
    }
}

// 提示选项
// 对齐 Rust: gix_prompt::Options
public class Options {
    public var askpass: ?String
    public var mode: Mode

    public init() {
        this.askpass = None
        this.mode = Mode.Hidden
    }

    public init(askpass: ?String, mode: Mode) {
        this.askpass = askpass
        this.mode = mode
    }
}

// 提示错误
// 对齐 Rust: gix_prompt::Error
public enum PromptError {
    | Disabled
    | UnsupportedPlatform
    | AskpassFailed(String)
    | IoError(String)

    public operator func ==(that: PromptError): Bool {
        match (this) {
            case Disabled => match (that) {
                case Disabled => true;
                case _ => false
            }
            case UnsupportedPlatform => match (that) {
                case UnsupportedPlatform => true;
                case _ => false
            }
            case AskpassFailed(s1) => match (that) {
                case AskpassFailed(s2) => s1 == s2;
                case _ => false
            }
            case IoError(s1) => match (that) {
                case IoError(s2) => s1 == s2;
                case _ => false
            }
        }
    }

    public operator func !=(that: PromptError): Bool {
        !(this == that)
    }
}

// 对齐 Rust: gix_prompt::ask
// 使用 askpass 程序获取用户输入
// 返回 Some(output) 成功，None 失败
public func ask(prompt: String, opts: Options): ?String {
    if (opts.mode == Mode.Disable) {
        return None
    }
    if (let Some(askpassProg) <- opts.askpass) {
        try {
            var result = executeWithOutput(askpassProg, [prompt])
            var (exitCode, stdoutBytes, _) = result
            if (exitCode != 0) {
                return None
            }
            var output = String.fromUtf8(stdoutBytes)
            // 去掉尾部 \n 和 \r
            var len = output.size
            if (len > 0 && output[len - 1] == 10) {
                output = output[0..len - 1]
                len = output.size
            }
            if (len > 0 && output[len - 1] == 13) {
                output = output[0..len - 1]
            }
            return Some(output)
        } catch (_: Exception) {
            return None
        }
    }
    None
}

// 对齐 Rust: gix_prompt::Options::apply_environment
// 从环境变量中读取 GIT_ASKPASS、SSH_ASKPASS、GIT_TERMINAL_PROMPT
public func applyEnvironment(opts: Options, useGitAskpass: Bool, useSshAskpass: Bool, useGitTerminalPrompt: Bool): Options {
    var result = Options(opts.askpass, opts.mode)
    if (useGitAskpass) {
        var gitAskpass = getVariable("GIT_ASKPASS")
        if (let Some(val) <- gitAskpass) {
            result.askpass = Some(val)
        }
    }
    if (result.askpass.isNone() && useSshAskpass) {
        var sshAskpass = getVariable("SSH_ASKPASS")
        if (let Some(val) <- sshAskpass) {
            result.askpass = Some(val)
        }
    }
    if (useGitTerminalPrompt) {
        var terminalPrompt = getVariable("GIT_TERMINAL_PROMPT")
        if (let Some(val) <- terminalPrompt) {
            if (val == "0" || val == "false" || val == "False" || val == "FALSE") {
                result.mode = Mode.Disable
            }
        }
    }
    result
}

// 对齐 Rust: gix_prompt::openly
public func askOpenly(prompt: String): ?String {
    ask(prompt, Options(None, Mode.Visible))
}

// 对齐 Rust: gix_prompt::securely
public func askSecurely(prompt: String): ?String {
    ask(prompt, Options(None, Mode.Hidden))
}
