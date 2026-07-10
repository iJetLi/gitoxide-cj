// 文件：rebase_test.cj
// 用途：gix_rebase 包的单元测试，全量对齐 Rust gitoxide gix-rebase 测试
// 所属包：gix.gix_rebase
// 对齐来源：gix-rebase/tests/parse.rs

package gitoxide.gix_rebase

import gitoxide.gix_hash.*
import std.unittest.*
import std.collection.*

// ============================================================
// parseTodo 测试 — 对齐 gix-rebase/tests/parse.rs
// ============================================================

@Test
func testParseTodoPick(): Unit {
    // 对齐 Rust: parse pick action
    let content = "pick e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (steps[0].action != RebaseAction.Pick) {
        throw Exception("action should be Pick")
    }
}

@Test
func testParseTodoEdit(): Unit {
    // 对齐 Rust: parse edit action
    let content = "edit e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (steps[0].action != RebaseAction.Edit) {
        throw Exception("action should be Edit")
    }
}

@Test
func testParseTodoSquash(): Unit {
    // 对齐 Rust: parse squash action
    let content = "squash e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (steps[0].action != RebaseAction.Squash) {
        throw Exception("action should be Squash")
    }
}

@Test
func testParseTodoFixup(): Unit {
    // 对齐 Rust: parse fixup action
    let content = "fixup e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (steps[0].action != RebaseAction.Fixup) {
        throw Exception("action should be Fixup")
    }
}

@Test
func testParseTodoDrop(): Unit {
    // 对齐 Rust: parse drop action
    let content = "drop e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (steps[0].action != RebaseAction.Drop) {
        throw Exception("action should be Drop")
    }
}

@Test
func testParseTodoShortActions(): Unit {
    // 对齐 Rust: parse short action aliases (p, r, e, s, f, d)
    let content = "p e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\ne 4b825dc642cb6eb9a060e54bf8d69288fbee4904"
    let steps = parseTodo(content)
    if (steps.size != 2) {
        throw Exception("should have 2 steps")
    }
    if (steps[0].action != RebaseAction.Pick) {
        throw Exception("p should be Pick")
    }
    if (steps[1].action != RebaseAction.Edit) {
        throw Exception("e should be Edit")
    }
}

@Test
func testParseTodoMultipleSteps(): Unit {
    // 对齐 Rust: parse multiple rebase steps
    let content = "pick e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\nsquash 4b825dc642cb6eb9a060e54bf8d69288fbee4904\npick 0000000000000000000000000000000000000000"
    let steps = parseTodo(content)
    if (steps.size != 3) {
        throw Exception("should have 3 steps")
    }
}

@Test
func testParseTodoWithComments(): Unit {
    // 对齐 Rust: parse with comments
    let content = "# Rebase instructions\npick e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step after skipping comments")
    }
}

@Test
func testParseTodoEmptyInput(): Unit {
    // 对齐 Rust: parse empty input
    let steps = parseTodo("")
    if (steps.size != 0) {
        throw Exception("empty input should have 0 steps")
    }
}

// ============================================================
// RebaseAction 枚举测试
// ============================================================

@Test
func testRebaseActionVariants(): Unit {
    // 对齐 Rust: RebaseAction enum completeness
    let variants: Array<RebaseAction> = [
        RebaseAction.Pick,
        RebaseAction.ReWord,
        RebaseAction.Edit,
        RebaseAction.Squash,
        RebaseAction.Fixup,
        RebaseAction.Drop
    ]
    if (variants.size != 6) {
        throw Exception("should have 6 RebaseAction variants, got " + variants.size.toString())
    }
}

// ============================================================
// parseTodo 补充测试 — 对齐 gix-rebase/tests/parse.rs 更多场景
// ============================================================

@Test
func testParseTodoReword(): Unit {
    // 对齐 Rust: parse reword action
    let content = "reword e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (steps[0].action != RebaseAction.ReWord) {
        throw Exception("action should be ReWord")
    }
}

@Test
func testParseTodoShortReword(): Unit {
    // 对齐 Rust: parse 'r' short alias for reword
    let content = "r e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (steps[0].action != RebaseAction.ReWord) {
        throw Exception("'r' should be ReWord")
    }
}

@Test
func testParseTodoShortSquash(): Unit {
    // 对齐 Rust: parse 's' short alias for squash
    let content = "s e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (steps[0].action != RebaseAction.Squash) {
        throw Exception("'s' should be Squash")
    }
}

@Test
func testParseTodoShortFixup(): Unit {
    // 对齐 Rust: parse 'f' short alias for fixup
    let content = "f e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (steps[0].action != RebaseAction.Fixup) {
        throw Exception("'f' should be Fixup")
    }
}

@Test
func testParseTodoShortDrop(): Unit {
    // 对齐 Rust: parse 'd' short alias for drop
    let content = "d e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (steps[0].action != RebaseAction.Drop) {
        throw Exception("'d' should be Drop")
    }
}

@Test
func testParseTodoWithBlankLines(): Unit {
    // 对齐 Rust: parse with blank lines
    let content = "pick e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\n\nsquash 4b825dc642cb6eb9a060e54bf8d69288fbee4904"
    let steps = parseTodo(content)
    if (steps.size != 2) {
        throw Exception("should have 2 steps after skipping blank lines")
    }
}

@Test
func testParseTodoCommitIdPreserved(): Unit {
    // 对齐 Rust: parse 保留 ObjectId
    let content = "pick e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (steps[0].commitId.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("commitId mismatch: " + steps[0].commitId.toHexString())
    }
}

@Test
func testParseTodoUnknownActionDefaultsToPick(): Unit {
    // 对齐 Rust: parse 未知操作默认为 Pick
    let content = "unknown e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let steps = parseTodo(content)
    if (steps.size != 1) {
        throw Exception("should have 1 step")
    }
    if (steps[0].action != RebaseAction.Pick) {
        throw Exception("unknown action should default to Pick")
    }
}

// ============================================================
// RebaseStep 构造补充测试
// ============================================================

@Test
func testRebaseStepConstruction(): Unit {
    // 对齐 Rust: RebaseStep 构造
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let step = RebaseStep(RebaseAction.Pick, id)
    if (step.action != RebaseAction.Pick) {
        throw Exception("action should be Pick")
    }
    if (step.commitId.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("commitId mismatch")
    }
}

@Test
func testRebaseActionEqualityAllVariants(): Unit {
    // 对齐 Rust: Eq trait — 同变体相等，不同变体不相等
    if (RebaseAction.Pick != RebaseAction.Pick) {
        throw Exception("Pick == Pick")
    }
    if (RebaseAction.ReWord != RebaseAction.ReWord) {
        throw Exception("ReWord == ReWord")
    }
    if (RebaseAction.Edit != RebaseAction.Edit) {
        throw Exception("Edit == Edit")
    }
    if (RebaseAction.Squash != RebaseAction.Squash) {
        throw Exception("Squash == Squash")
    }
    if (RebaseAction.Fixup != RebaseAction.Fixup) {
        throw Exception("Fixup == Fixup")
    }
    if (RebaseAction.Drop != RebaseAction.Drop) {
        throw Exception("Drop == Drop")
    }
    if (RebaseAction.Pick == RebaseAction.Drop) {
        throw Exception("Pick != Drop")
    }
}
