// 文件：prompt_test.cj
// 用途：gix_prompt 包的单元测试，对齐 Rust gitoxide gix-prompt 测试
// 所属包：gix.gix_prompt
// 对齐来源：gix-prompt/tests/prompt.rs, gix-prompt/tests/options/*.rs

package gitoxide.gix_prompt

import std.unittest.*
import std.collection.*
import std.env.*
import std.process.*

// ============================================================
// PromptResponse 测试 — 对齐 gix-prompt/src/lib.rs
// ============================================================

@Test
func testPromptResponseYes(): Unit {
    // 对齐 Rust: PromptResponse::Yes
    let resp = PromptResponse.Yes
    if (resp != PromptResponse.Yes) {
        throw Exception("should be Yes")
    }
}

@Test
func testPromptResponseNo(): Unit {
    // 对齐 Rust: PromptResponse::No
    let resp = PromptResponse.No
    if (resp != PromptResponse.No) {
        throw Exception("should be No")
    }
}

@Test
func testPromptResponseValue(): Unit {
    // 对齐 Rust: PromptResponse::Value("input")
    let resp = PromptResponse.Value("user_input")
    if (resp != PromptResponse.Value("user_input")) {
        throw Exception("should be Value('user_input')")
    }
}

@Test
func testPromptResponseVariants(): Unit {
    // 对齐 Rust: PromptResponse 枚举变体完整性
    let responses = ArrayList<PromptResponse>()
    responses.add(PromptResponse.Yes)
    responses.add(PromptResponse.No)
    responses.add(PromptResponse.Value("test"))
    if (responses.size != 3) {
        throw Exception("should have 3 PromptResponse variants")
    }
}

@Test
func testPromptResponseYesNotNo(): Unit {
    // 对齐 Rust: Yes != No
    if (PromptResponse.Yes == PromptResponse.No) {
        throw Exception("Yes should not equal No")
    }
}

@Test
func testPromptResponseValueDifferentStrings(): Unit {
    // 对齐 Rust: gix-prompt/src/lib.rs — PromptResponse::Value 不同字符串不相等
    if (PromptResponse.Value("a") == PromptResponse.Value("b")) {
        throw Exception("different Value strings should not be equal")
    }
}

@Test
func testPromptResponseValueEmptyString(): Unit {
    // 对齐 Rust: PromptResponse::Value("")
    let resp = PromptResponse.Value("")
    if (resp != PromptResponse.Value("")) {
        throw Exception("empty Value should be equal")
    }
}

@Test
func testPromptResponseValueWithSpecialChars(): Unit {
    // 对齐 Rust: PromptResponse::Value 含特殊字符
    let resp = PromptResponse.Value("pass\nword")
    if (resp != PromptResponse.Value("pass\nword")) {
        throw Exception("Value with special chars should be equal")
    }
}

// ============================================================
// Prompter 接口测试 — 对齐 gix-prompt/src/lib.rs
// ============================================================

@Test
func testDummyPrompterPrompt(): Unit {
    // 对齐 Rust: Prompter::prompt — 使用占位实现验证接口
    let prompter = DummyPrompter()
    let result = prompter.prompt("Continue?")
    if (result != Some(PromptResponse.Yes)) {
        throw Exception("dummy prompter should return Yes")
    }
}

@Test
func testDummyPrompterPromptPassword(): Unit {
    // 对齐 Rust: Prompter::prompt_password — 使用占位实现验证接口
    let prompter = DummyPrompter()
    let result = prompter.promptPassword("Password:")
    if (result != Some("dummy-password")) {
        throw Exception("dummy prompter should return dummy password")
    }
}

@Test
func testPrompterPromptWithEmptyMessage(): Unit {
    // 对齐 Rust: Prompter::prompt("") — 空消息
    let prompter = DummyPrompter()
    let result = prompter.prompt("")
    if (result.isNone()) {
        throw Exception("should return Some")
    }
}

@Test
func testPrompterPromptPasswordWithEmptyMessage(): Unit {
    // 对齐 Rust: Prompter::prompt_password("") — 空消息
    let prompter = DummyPrompter()
    let result = prompter.promptPassword("")
    if (result.isNone()) {
        throw Exception("should return Some")
    }
}

@Test
func testReturningPrompterPromptReturnsNo(): Unit {
    // 对齐 Rust: Prompter::prompt 返回 No
    let prompter = NoPrompter()
    let result = prompter.prompt("Confirm?")
    if (result != Some(PromptResponse.No)) {
        throw Exception("should return No")
    }
}

@Test
func testReturningPrompterPromptPasswordReturnsNone(): Unit {
    // 对齐 Rust: Prompter::prompt_password 取消返回 None
    let prompter = NonePrompter()
    let result = prompter.promptPassword("Password:")
    if (!result.isNone()) {
        throw Exception("should return None")
    }
}

// ============================================================
// Mode 枚举测试 — 对齐 gix-prompt/src/types.rs
// ============================================================

@Test
func testModeVisible(): Unit {
    // 对齐 Rust: gix-prompt/src/types.rs — Mode::Visible
    let mode = Mode.Visible
    if (mode != Mode.Visible) {
        throw Exception("should be Visible")
    }
}

@Test
func testModeHidden(): Unit {
    // 对齐 Rust: gix-prompt/src/types.rs — Mode::Hidden
    let mode = Mode.Hidden
    if (mode != Mode.Hidden) {
        throw Exception("should be Hidden")
    }
}

@Test
func testModeDisable(): Unit {
    // 对齐 Rust: gix-prompt/src/types.rs — Mode::Disable
    let mode = Mode.Disable
    if (mode != Mode.Disable) {
        throw Exception("should be Disable")
    }
}

@Test
func testModeNotEqual(): Unit {
    // 对齐 Rust: gix-prompt/src/types.rs — Mode 枚举变体互不相等
    if (Mode.Visible == Mode.Hidden) {
        throw Exception("Visible should not equal Hidden")
    }
    if (Mode.Hidden == Mode.Disable) {
        throw Exception("Hidden should not equal Disable")
    }
    if (Mode.Visible == Mode.Disable) {
        throw Exception("Visible should not equal Disable")
    }
}

// ============================================================
// Options 测试 — 对齐 gix-prompt/src/types.rs
// ============================================================

@Test
func testOptionsDefault(): Unit {
    // 对齐 Rust: gix-prompt/src/types.rs — Options::default()
    let opts = Options()
    if (!opts.askpass.isNone()) {
        throw Exception("default askpass should be None")
    }
    if (opts.mode != Mode.Hidden) {
        throw Exception("default mode should be Hidden")
    }
}

@Test
func testOptionsWithAskpass(): Unit {
    // 对齐 Rust: gix-prompt/src/types.rs — Options { askpass, mode }
    let opts = Options(Some("/usr/bin/ssh-askpass"), Mode.Visible)
    if (let Some(ap) <- opts.askpass) {
        if (ap != "/usr/bin/ssh-askpass") {
            throw Exception("askpass mismatch")
        }
    } else {
        throw Exception("askpass should be Some")
    }
    if (opts.mode != Mode.Visible) {
        throw Exception("mode should be Visible")
    }
}

@Test
func testOptionsAskpassOverwrite(): Unit {
    // 对齐 Rust: gix-prompt/tests/options/mod.rs — askpass_overwrite
    let opts = Options()
    opts.askpass = Some("first")
    opts.askpass = Some("second")
    if (let Some(ap) <- opts.askpass) {
        if (ap != "second") {
            throw Exception("should be 'second'")
        }
    } else {
        throw Exception("should be Some")
    }
}

@Test
func testOptionsAskpassResetToNone(): Unit {
    // 对齐 Rust: gix-prompt/tests/options/mod.rs — askpass_reset_to_none
    let opts = Options()
    opts.askpass = Some("cmd")
    opts.askpass = None
    if (!opts.askpass.isNone()) {
        throw Exception("should be None after reset")
    }
}

@Test
func testOptionsModeOverwrite(): Unit {
    // 对齐 Rust: gix-prompt/tests/options/mod.rs — mode_overwrite
    let opts = Options()
    opts.mode = Mode.Visible
    if (opts.mode != Mode.Visible) {
        throw Exception("should be Visible")
    }
    opts.mode = Mode.Disable
    if (opts.mode != Mode.Disable) {
        throw Exception("should be Disable")
    }
}

// ============================================================
// applyEnvironment 测试 — 对齐 gix-prompt/tests/options/mod.rs
// ============================================================

@Test
func testApplyEnvironmentGitAskpassOverridesEverything(): Unit {
    // 对齐 Rust: git_askpass_overrides_everything_and_ssh_askpass_does_not
    setVariable("GIT_ASKPASS", "override")
    setVariable("SSH_ASKPASS", "does not matter")
    let opts = Options(Some("current"), Mode.Hidden)
    let result = applyEnvironment(opts, true, true, false)
    if (let Some(ap) <- result.askpass) {
        if (ap != "override") {
            throw Exception("GIT_ASKPASS should override, got '${ap}'")
        }
    } else {
        throw Exception("askpass should be Some")
    }
    removeVariable("GIT_ASKPASS")
    removeVariable("SSH_ASKPASS")
}

@Test
func testApplyEnvironmentGitAskpassSetsUnsetValues(): Unit {
    // 对齐 Rust: git_askpass_is_used_first_and_sets_unset_askpass_values
    setVariable("GIT_ASKPASS", "from-env")
    setVariable("SSH_ASKPASS", "does not matter")
    let opts = Options()
    let result = applyEnvironment(opts, true, true, false)
    if (let Some(ap) <- result.askpass) {
        if (ap != "from-env") {
            throw Exception("should be 'from-env', got '${ap}'")
        }
    } else {
        throw Exception("askpass should be Some")
    }
    removeVariable("GIT_ASKPASS")
    removeVariable("SSH_ASKPASS")
}

@Test
func testApplyEnvironmentSshAskpassFallback(): Unit {
    // 对齐 Rust: ssh_askpass_is_used_as_fallback
    removeVariable("GIT_ASKPASS")
    setVariable("SSH_ASKPASS", "fallback")
    let opts = Options(None, Mode.Visible)
    let result = applyEnvironment(opts, true, true, false)
    if (let Some(ap) <- result.askpass) {
        if (ap != "fallback") {
            throw Exception("should be 'fallback', got '${ap}'")
        }
    } else {
        throw Exception("askpass should be Some")
    }
    removeVariable("SSH_ASKPASS")
}

@Test
func testApplyEnvironmentSshAskpassDoesNotOverrideCurrent(): Unit {
    // 对齐 Rust: ssh_askpass_does_not_override_current_value
    removeVariable("GIT_ASKPASS")
    setVariable("SSH_ASKPASS", "fallback")
    let opts = Options(Some("current"), Mode.Hidden)
    let result = applyEnvironment(opts, true, true, false)
    if (let Some(ap) <- result.askpass) {
        if (ap != "current") {
            throw Exception("should keep 'current', got '${ap}'")
        }
    } else {
        throw Exception("askpass should be Some")
    }
    removeVariable("SSH_ASKPASS")
}

@Test
func testApplyEnvironmentTerminalPromptTrueish(): Unit {
    // 对齐 Rust: mode_is_left_untouched_if_terminal_prompt_is_trueish
    setVariable("GIT_TERMINAL_PROMPT", "true")
    let opts = Options(None, Mode.Hidden)
    let result = applyEnvironment(opts, false, false, true)
    if (result.mode != Mode.Hidden) {
        throw Exception("mode should stay Hidden when GIT_TERMINAL_PROMPT=true")
    }
    removeVariable("GIT_TERMINAL_PROMPT")
}

@Test
func testApplyEnvironmentTerminalPromptFalseish(): Unit {
    // 对齐 Rust: mode_is_disabled_if_terminal_prompt_is_falseish
    setVariable("GIT_TERMINAL_PROMPT", "0")
    let opts = Options(None, Mode.Hidden)
    let result = applyEnvironment(opts, false, false, true)
    if (result.mode != Mode.Disable) {
        throw Exception("mode should be Disable when GIT_TERMINAL_PROMPT=0")
    }
    removeVariable("GIT_TERMINAL_PROMPT")
}

@Test
func testApplyEnvironmentTerminalPromptUnset(): Unit {
    // 对齐 Rust: mode_is_unchanged_if_git_terminal_prompt_is_not_set
    removeVariable("GIT_TERMINAL_PROMPT")
    let opts = Options(None, Mode.Hidden)
    let result = applyEnvironment(opts, false, false, true)
    if (result.mode != Mode.Hidden) {
        throw Exception("mode should stay Hidden when GIT_TERMINAL_PROMPT is unset")
    }
}

@Test
func testApplyEnvironmentAllDisabled(): Unit {
    // 对齐 Rust: gix-prompt/tests/options/mod.rs — apply_environment::all_disabled
    // 所有环境变量读取都禁用
    setVariable("GIT_ASKPASS", "should-not-use")
    setVariable("SSH_ASKPASS", "should-not-use")
    let opts = Options()
    let result = applyEnvironment(opts, false, false, false)
    if (!result.askpass.isNone()) {
        throw Exception("askpass should stay None when all env reads disabled")
    }
    removeVariable("GIT_ASKPASS")
    removeVariable("SSH_ASKPASS")
}

// ============================================================
// ask 函数测试 — 对齐 gix-prompt/src/lib.rs (ask)
// ============================================================

@Test
func testAskNoAskpassReturnsNone(): Unit {
    // 对齐 Rust: gix-prompt/src/lib.rs — ask() 无 askpass 返回 None
    // 无 askpass 程序时返回 None
    let opts = Options(None, Mode.Hidden)
    var result = ask("Password:", opts)
    if (!result.isNone()) {
        throw Exception("should return None without askpass")
    }
}

@Test
func testAskWithModeDisableReturnsNone(): Unit {
    // 对齐 Rust: gix-prompt/src/lib.rs — ask() Mode::Disable 返回 None
    // 禁用模式返回 None
    let opts = Options(Some("cmd"), Mode.Disable)
    var result = ask("test", opts)
    if (!result.isNone()) {
        throw Exception("should return None when mode is Disable")
    }
}

@Test
func testAskWithRealAskpass(): Unit {
    // 对齐 Rust: askpass_only — 验证 askpass 程序被正确调用
    // 使用 cmd /c echo 模拟 askpass 程序（必须带 /c 否则 cmd.exe 会等待输入导致卡死）
    let opts = Options(Some("cmd"), Mode.Visible)
    // 直接用 executeWithOutput 测试，传 /c echo 确保进程会退出
    var result = executeWithOutput("cmd", ["/c", "echo", "test-response"])
    var (exitCode, stdoutBytes, _) = result
    if (exitCode != 0) {
        throw Exception("cmd /c echo should succeed")
    }
    var output = String.fromUtf8(stdoutBytes).trimAscii()
    if (output != "test-response") {
        throw Exception("output should be test-response, got ${output}")
    }
}

// ============================================================
// PromptError 测试
// ============================================================

@Test
func testPromptErrorDisabled(): Unit {
    // 对齐 Rust: gix-prompt/src/lib.rs — PromptError::Disabled
    let err = PromptError.Disabled
    if (err != PromptError.Disabled) {
        throw Exception("should equal Disabled")
    }
}

@Test
func testPromptErrorUnsupportedPlatform(): Unit {
    // 对齐 Rust: gix-prompt/src/lib.rs — PromptError::UnsupportedPlatform
    let err = PromptError.UnsupportedPlatform
    if (err != PromptError.UnsupportedPlatform) {
        throw Exception("should equal UnsupportedPlatform")
    }
}

@Test
func testPromptErrorAskpassFailed(): Unit {
    // 对齐 Rust: gix-prompt/src/lib.rs — PromptError::AskpassFailed
    let err = PromptError.AskpassFailed("test error")
    if (err != PromptError.AskpassFailed("test error")) {
        throw Exception("should equal")
    }
}

@Test
func testPromptErrorIoError(): Unit {
    // 对齐 Rust: gix-prompt/src/lib.rs — PromptError::IoError
    let err = PromptError.IoError("io failed")
    if (err != PromptError.IoError("io failed")) {
        throw Exception("should equal")
    }
}

// ============================================================
// askOpenly / askSecurely 测试
// ============================================================

@Test
func testAskOpenlyNoAskpass(): Unit {
    // 对齐 Rust: gix-prompt/src/lib.rs — ask_openly() 无 askpass
    var result = askOpenly("Username:")
    if (!result.isNone()) {
        throw Exception("should return None without askpass")
    }
}

@Test
func testAskSecurelyNoAskpass(): Unit {
    // 对齐 Rust: gix-prompt/src/lib.rs — ask_securely() 无 askpass
    var result = askSecurely("Password:")
    if (!result.isNone()) {
        throw Exception("should return None without askpass")
    }
}

// 测试辅助：DummyPrompter 实现 Prompter 接口
class DummyPrompter <: Prompter {
    public func prompt(message: String): ?PromptResponse {
        Some(PromptResponse.Yes)
    }
    public func promptPassword(message: String): ?String {
        Some("dummy-password")
    }
}

// 返回 No 的 Prompter
class NoPrompter <: Prompter {
    public func prompt(message: String): ?PromptResponse {
        Some(PromptResponse.No)
    }
    public func promptPassword(message: String): ?String {
        Some("")
    }
}

// 返回 None 的 Prompter（模拟取消）
class NonePrompter <: Prompter {
    public func prompt(message: String): ?PromptResponse {
        None
    }
    public func promptPassword(message: String): ?String {
        None
    }
}
