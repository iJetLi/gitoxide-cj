// 文件：sequencer_test.cj
// 用途：gix_sequencer 包的单元测试，全量对齐 Rust gitoxide gix-sequencer 测试
// 所属包：gix.gix_sequencer
// 对齐来源：gix-sequencer/tests/parse.rs

package gitoxide.gix_sequencer

import gitoxide.gix_hash.*
import std.unittest.*
import std.collection.*

// ============================================================
// TodoList.parse 测试 — 对齐 gix-sequencer/tests/parse.rs
// ============================================================

@Test
func testTodoListParseSingleStep(): Unit {
    // 对齐 Rust: parse single todo step
    let content = "pick e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let list = TodoList.parse(content)
    if (list.steps.size != 1) {
        throw Exception("should have 1 step, got " + list.steps.size.toString())
    }
    if (list.steps[0].action != "pick") {
        throw Exception("action should be 'pick'")
    }
    if (list.steps[0].commitId.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("commitId mismatch")
    }
}

@Test
func testTodoListParseMultipleSteps(): Unit {
    // 对齐 Rust: parse multiple todo steps
    let content = "pick e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\nedit 4b825dc642cb6eb9a060e54bf8d69288fbee4904"
    let list = TodoList.parse(content)
    if (list.steps.size != 2) {
        throw Exception("should have 2 steps, got " + list.steps.size.toString())
    }
    if (list.steps[1].action != "edit") {
        throw Exception("second action should be 'edit'")
    }
}

@Test
func testTodoListParseWithComments(): Unit {
    // 对齐 Rust: parse with comments
    let content = "# This is a comment\npick e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\n# Another comment"
    let list = TodoList.parse(content)
    if (list.steps.size != 1) {
        throw Exception("should have 1 step after skipping comments")
    }
}

@Test
func testTodoListParseEmptyLines(): Unit {
    // 对齐 Rust: parse with empty lines
    let content = "\npick e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\n\n"
    let list = TodoList.parse(content)
    if (list.steps.size != 1) {
        throw Exception("should have 1 step after skipping empty lines")
    }
}

@Test
func testTodoListParseEmptyInput(): Unit {
    // 对齐 Rust: parse empty input
    let list = TodoList.parse("")
    if (list.steps.size != 0) {
        throw Exception("empty input should have 0 steps")
    }
}

// ============================================================
// TodoStep 构造测试
// ============================================================

@Test
func testTodoStepConstruction(): Unit {
    // 对齐 Rust: TodoStep construction
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let step = TodoStep("squash", id)
    if (step.action != "squash") {
        throw Exception("action mismatch")
    }
    if (step.commitId.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("commitId mismatch")
    }
}

// ============================================================
// TodoList.parse 补充测试 — 对齐 gix-sequencer/src/lib.rs
// ============================================================

@Test
func testTodoListParseMixedActions(): Unit {
    // 对齐 Rust: parse mixed actions (pick, edit, squash, fixup, reword)
    let content = "pick e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\nedit 4b825dc642cb6eb9a060e54bf8d69288fbee4904\nsquash ffa700b4aca13b80cb6b98a078e7c96804f8e0ec"
    let list = TodoList.parse(content)
    if (list.steps.size != 3) {
        throw Exception("should have 3 steps")
    }
    if (list.steps[0].action != "pick") {
        throw Exception("first action should be pick")
    }
    if (list.steps[1].action != "edit") {
        throw Exception("second action should be edit")
    }
    if (list.steps[2].action != "squash") {
        throw Exception("third action should be squash")
    }
}

@Test
func testTodoListParseOnlyComments(): Unit {
    // 对齐 Rust: parse only comments
    let content = "# comment 1\n# comment 2\n# comment 3"
    let list = TodoList.parse(content)
    if (list.steps.size != 0) {
        throw Exception("should have 0 steps with only comments")
    }
}

@Test
func testTodoListParseOnlyEmptyLines(): Unit {
    // 对齐 Rust: parse only empty lines
    let content = "\n\n\n"
    let list = TodoList.parse(content)
    if (list.steps.size != 0) {
        throw Exception("should have 0 steps with only empty lines")
    }
}

@Test
func testTodoListParseFixupAction(): Unit {
    // 对齐 Rust: parse fixup action
    let content = "fixup e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let list = TodoList.parse(content)
    if (list.steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (list.steps[0].action != "fixup") {
        throw Exception("action should be fixup")
    }
}

@Test
func testTodoListParseRewordAction(): Unit {
    // 对齐 Rust: parse reword action
    let content = "reword e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let list = TodoList.parse(content)
    if (list.steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (list.steps[0].action != "reword") {
        throw Exception("action should be reword")
    }
}

@Test
func testTodoListParseInterleavedCommentsAndSteps(): Unit {
    // 对齐 Rust: parse interleaved comments and steps
    let content = "# Rebase instructions\npick e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\n# Another comment\nedit 4b825dc642cb6eb9a060e54bf8d69288fbee4904"
    let list = TodoList.parse(content)
    if (list.steps.size != 2) {
        throw Exception("should have 2 steps")
    }
}

@Test
func testTodoStepEquality(): Unit {
    // 对齐 Rust: TodoStep — 不同 action 和 commitId
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let step1 = TodoStep("pick", id1)
    let step2 = TodoStep("pick", id2)
    let step3 = TodoStep("edit", id1)
    if (step1.action != step2.action) {
        throw Exception("same action should match")
    }
    if (step1.commitId.toHexString() == step2.commitId.toHexString()) {
        throw Exception("different commitIds should not match")
    }
    if (step1.action == step3.action) {
        throw Exception("different actions should not match")
    }
}
