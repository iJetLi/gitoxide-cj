// 文件：worktree_state_test.cj
// 用途：gix_worktree_state 包的单元测试，对齐 Rust gitoxide gix-worktree-state 测试
// 所属包：gix.gix_worktree_state
// 对齐来源：gix-worktree-state/tests/worktree-state/*.rs

package gitoxide.gix_worktree_state

import std.unittest.*

// ============================================================
// WorktreeState 默认状态测试 — 对齐 gix-worktree-state/tests/worktree-state/state.rs
// ============================================================

@Test
func testWorktreeStateDefaultClean(): Unit {
    // 对齐 Rust: WorktreeState::default() — 默认为干净状态
    let state = WorktreeState()
    if (!state.isClean) {
        throw Exception("should be clean by default")
    }
    if (state.hasUnstagedChanges) {
        throw Exception("should have no unstaged changes by default")
    }
    if (state.hasUncommittedChanges) {
        throw Exception("should have no uncommitted changes by default")
    }
}

@Test
func testWorktreeStateWithUnstagedChanges(): Unit {
    // 对齐 Rust: WorktreeState 标记未暂存变更
    let state = WorktreeState()
    state.hasUnstagedChanges = true
    state.isClean = false
    if (state.isClean) {
        throw Exception("should not be clean with unstaged changes")
    }
    if (!state.hasUnstagedChanges) {
        throw Exception("should have unstaged changes")
    }
}

@Test
func testWorktreeStateWithUncommittedChanges(): Unit {
    // 对齐 Rust: WorktreeState 标记已暂存但未提交变更
    let state = WorktreeState()
    state.hasUncommittedChanges = true
    state.isClean = false
    if (state.isClean) {
        throw Exception("should not be clean with uncommitted changes")
    }
    if (!state.hasUncommittedChanges) {
        throw Exception("should have uncommitted changes")
    }
}

@Test
func testWorktreeStateBothChanges(): Unit {
    // 对齐 Rust: WorktreeState 同时有未暂存和未提交变更
    let state = WorktreeState()
    state.hasUnstagedChanges = true
    state.hasUncommittedChanges = true
    state.isClean = false
    if (state.isClean) {
        throw Exception("should not be clean")
    }
    if (!state.hasUnstagedChanges || !state.hasUncommittedChanges) {
        throw Exception("should have both types of changes")
    }
}

@Test
func testWorktreeStateResetToClean(): Unit {
    // 对齐 Rust: WorktreeState 可重置为干净状态
    let state = WorktreeState()
    state.hasUnstagedChanges = true
    state.hasUncommittedChanges = true
    state.isClean = false
    state.isClean = true
    state.hasUnstagedChanges = false
    state.hasUncommittedChanges = false
    if (!state.isClean) {
        throw Exception("should be clean after reset")
    }
}

@Test
func testWorktreeStateOnlyUnstaged(): Unit {
    // 对齐 Rust: WorktreeState 仅未暂存变更
    let state = WorktreeState()
    state.hasUnstagedChanges = true
    state.isClean = false
    if (state.hasUncommittedChanges) {
        throw Exception("should not have uncommitted changes")
    }
    if (state.isClean) {
        throw Exception("should not be clean")
    }
}

@Test
func testWorktreeStateOnlyUncommitted(): Unit {
    // 对齐 Rust: WorktreeState 仅未提交变更
    let state = WorktreeState()
    state.hasUncommittedChanges = true
    state.isClean = false
    if (state.hasUnstagedChanges) {
        throw Exception("should not have unstaged changes")
    }
    if (state.isClean) {
        throw Exception("should not be clean")
    }
}

@Test
func testWorktreeStateIsCleanTrueButHasChanges(): Unit {
    // 对齐 Rust: WorktreeState 逻辑不一致状态（isClean=true 但有变更）
    // 这是 API 使用的逻辑错误，但类型系统不阻止
    let state = WorktreeState()
    state.hasUnstagedChanges = true
    // 不修改 isClean — 这是不一致状态
    if (!state.isClean) {
        throw Exception("isClean should still be true (inconsistent but allowed)")
    }
    if (!state.hasUnstagedChanges) {
        throw Exception("should have unstaged changes")
    }
}

@Test
func testWorktreeStateMultipleToggles(): Unit {
    // 对齐 Rust: WorktreeState 多次切换状态
    let state = WorktreeState()
    state.hasUnstagedChanges = true
    state.isClean = false
    state.hasUnstagedChanges = false
    state.isClean = true
    if (!state.isClean) {
        throw Exception("should be clean after toggle")
    }
    if (state.hasUnstagedChanges) {
        throw Exception("should not have unstaged changes")
    }
}

// ============================================================
// 工作区文件系统集成测试
// ============================================================
// 【无法对齐】原版 gix-worktree-state 测试依赖工作区文件系统状态
// （含 checkout、stash、conflict 等场景），验证 WorktreeState
// 从实际工作区计算得出。仓颉中暂无法实现，待 gix_odb 与
// gix_test_utils 文件系统夹具支持完善后补充。
