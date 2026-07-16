// 文件：traverse_test.cj
// 用途：gix_traverse 包的单元测试，对齐 Rust gitoxide gix-traverse 测试
// 所属包：gix.gix_traverse
// 对齐来源：gix-traverse/tests/traverse/*.rs

package gitoxide.gix_traverse

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import std.collection.*
import std.unittest.*

// ============================================================
// CommitIter 构造测试 — 对齐 gix-traverse/tests/traverse/commit_iter.rs
// ============================================================

@Test
func testCommitIterConstruct(): Unit {
    // 对齐 Rust: CommitIter::new(start_id, finder)
    let startId = ObjectId.null(HashKind.Sha1)
    let finder = DummyFindObject()
    let iter = CommitIter(startId, finder)
    if (iter.stack.size != 1) {
        throw Exception("stack should contain start commit")
    }
    if (iter.visited.size != 0) {
        throw Exception("visited should be empty initially")
    }
}

@Test
func testCommitIterNextWithNoData(): Unit {
    // 对齐 Rust: CommitIter::next — DummyFindObject 返回 None
    // 【无法对齐】原版测试使用真实对象数据库（含提交图夹具），
    // 验证 next() 正确遍历提交图。仓颉中 DummyFindObject 始终返回 None。
    let startId = ObjectId.null(HashKind.Sha1)
    let finder = DummyFindObject()
    let iter = CommitIter(startId, finder)
    let result = iter.next()
    if (!result.isNone()) {
        throw Exception("next with no data should return None")
    }
}

@Test
func testCommitIterVisitedAfterNext(): Unit {
    // 对齐 Rust: next() 后 visited 集合应包含已处理的提交
    let startId = ObjectId.null(HashKind.Sha1)
    let finder = DummyFindObject()
    let iter = CommitIter(startId, finder)
    iter.next()
    if (iter.visited.size != 1) {
        throw Exception("visited should contain 1 entry after next()")
    }
}

@Test
func testCommitIterStackClearedAfterNext(): Unit {
    // 对齐 Rust: next() 消费栈顶元素
    let startId = ObjectId.null(HashKind.Sha1)
    let finder = DummyFindObject()
    let iter = CommitIter(startId, finder)
    iter.next()
    if (iter.stack.size != 0) {
        throw Exception("stack should be empty after next()")
    }
}

@Test
func testCommitIterVisitedContainsStartId(): Unit {
    // 对齐 Rust: visited 集合包含起始提交的 hex
    let startId = ObjectId.null(HashKind.Sha1)
    let finder = DummyFindObject()
    let iter = CommitIter(startId, finder)
    iter.next()
    if (!iter.visited.contains(startId.toHexString())) {
        throw Exception("visited should contain start id hex")
    }
}

@Test
func testCommitIterMultipleNextCalls(): Unit {
    // 对齐 Rust: 多次调用 next() — 全部返回 None（finder 无数据）
    let startId = ObjectId.null(HashKind.Sha1)
    let finder = DummyFindObject()
    let iter = CommitIter(startId, finder)
    iter.next()
    let result2 = iter.next()
    if (!result2.isNone()) {
        throw Exception("second next should return None")
    }
}

@Test
func testCommitIterWithRealId(): Unit {
    // 对齐 Rust: CommitIter 使用真实 ObjectId
    let startId = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let finder = DummyFindObject()
    let iter = CommitIter(startId, finder)
    if (iter.stack.size != 1) {
        throw Exception("stack should have 1 entry")
    }
    iter.next()
    if (!iter.visited.contains("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")) {
        throw Exception("visited should contain the real id")
    }
}

@Test
func testCommitIterFinderAccessible(): Unit {
    // 对齐 Rust: CommitIter 保留 finder 引用
    let startId = ObjectId.null(HashKind.Sha1)
    let finder = DummyFindObject()
    let iter = CommitIter(startId, finder)
    let found = iter.finder.findObject(startId)
    if (!found.isNone()) {
        throw Exception("dummy finder should return None")
    }
}

// ============================================================
// FindObject 接口测试 — 对齐 gix-traverse/src/lib.rs
// ============================================================

@Test
func testDummyFindObjectReturnsNone(): Unit {
    // 对齐 Rust: FindObject 接口可以被实现
    let finder = DummyFindObject()
    let id = ObjectId.null(HashKind.Sha1)
    if (!finder.findObject(id).isNone()) {
        throw Exception("dummy finder should return None")
    }
}

@Test
func testDummyFindObjectWithRealId(): Unit {
    // 对齐 Rust: FindObject 使用真实 ObjectId
    let finder = DummyFindObject()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    if (!finder.findObject(id).isNone()) {
        throw Exception("should return None")
    }
}

// ============================================================
// 提交遍历集成测试 — 对齐 gix-traverse/tests/traverse/*.rs
// ============================================================
// 【无法对齐】原版 traverse 测试依赖完整的 Git 仓库夹具（含提交图、
// 多分支、标签等），验证 CommitIter 正确遍历提交历史、去重、
// 按时间排序等。仓颉中暂无法实现，待 gix_odb 与 gix_test_utils
// 完善后补充。具体缺失的测试包括：
// - commit_iter 遍历线性提交历史
// - commit_iter 遍历分支合并（多父提交）
// - commit_iter 去重（菱形提交图）
// - tree 遍历（TreeIter）
// - 按时间排序遍历（Ancestors with sorting）

// 测试辅助：DummyFindObject 实现 FindObject 接口
class DummyFindObject <: FindObject {
    public func findObject(id: ObjectId): ?Data {
        None
    }
}

// ============================================================
// CommitIter 边界补充测试 — 对齐 gix-traverse 边界场景
// ============================================================

@Test
func testCommitIterWithSha256Id(): Unit {
    // 对齐 Rust: CommitIter 使用 Sha256 ObjectId
    let startId = ObjectId.null(HashKind.Sha256)
    let finder = DummyFindObject()
    let iter = CommitIter(startId, finder)
    if (iter.stack.size != 1) {
        throw Exception("stack should have 1 entry")
    }
    iter.next()
    if (iter.visited.size != 1) {
        throw Exception("visited should have 1 entry")
    }
}

@Test
func testCommitIterNextReturnsNoneAfterExhausted(): Unit {
    // 对齐 Rust: CommitIter 遍历完毕后所有 next() 返回 None
    let startId = ObjectId.null(HashKind.Sha1)
    let finder = DummyFindObject()
    let iter = CommitIter(startId, finder)
    iter.next()
    iter.next()
    iter.next()
    // 三次 next 后仍不崩溃
    if (iter.stack.size != 0) {
        throw Exception("stack should be empty")
    }
}

@Test
func testCommitIterVisitedSetGrowsCorrectly(): Unit {
    // 对齐 Rust: visited 集合只增加不减少
    let startId = ObjectId.null(HashKind.Sha1)
    let finder = DummyFindObject()
    let iter = CommitIter(startId, finder)
    if (iter.visited.size != 0) {
        throw Exception("initial visited should be 0")
    }
    iter.next()
    let sz1 = iter.visited.size
    iter.next()
    if (iter.visited.size != sz1) {
        throw Exception("visited should not shrink")
    }
}
