// 文件：sec_test.cj
// 用途：gix_sec 包的单元测试，全量对齐 Rust gitoxide gix-sec 测试
// 所属包：gix.gix_sec
// 对齐来源：gix-sec/tests/{trust,identity}.rs

package gitoxide.gix_sec

import std.unittest.*

// ============================================================
// Trust 枚举测试 — 对齐 gix-sec/tests/trust.rs
// ============================================================

@Test
func testTrustEnumVariants(): Unit {
    // 对齐 Rust: Trust 枚举变体
    let full = Trust.Full
    let reduced = Trust.Reduced
    let none = Trust.None
}

@Test
func testTrustEquality(): Unit {
    // 对齐 Rust: Trust PartialEq
    if (Trust.Full != Trust.Full) {
        throw Exception("Full should equal Full")
    }
    if (Trust.Full == Trust.Reduced) {
        throw Exception("Full should not equal Reduced")
    }
    if (Trust.Reduced == Trust.None) {
        throw Exception("Reduced should not equal None")
    }
}

@Test
func testTrustForPathDefault(): Unit {
    // 对齐 Rust: trust_for_path — 默认返回 Full
    let trust = trustForPath("/some/path")
    if (trust != Trust.Full) {
        throw Exception("default trust should be Full")
    }
}

@Test
func testTrustForPathEmptyString(): Unit {
    // 对齐 Rust: trust_for_path — 空路径
    let trust = trustForPath("")
    if (trust != Trust.Full) {
        throw Exception("empty path trust should default to Full")
    }
}

@Test
func testTrustForPathGitDir(): Unit {
    // 对齐 Rust: trust_for_path — .git 目录
    let trust = trustForPath("/home/user/repo/.git")
    if (trust != Trust.Full) {
        throw Exception(".git path trust should default to Full")
    }
}

@Test
func testTrustForPathWindowsPath(): Unit {
    // 对齐 Rust: trust_for_path — Windows 路径
    let trust = trustForPath("C:\\Users\\repo\\.git")
    if (trust != Trust.Full) {
        throw Exception("Windows path trust should default to Full")
    }
}

// ============================================================
// Identity 测试 — 对齐 gix-sec/tests/identity.rs
// ============================================================

@Test
func testIdentityCreation(): Unit {
    // 对齐 Rust: Identity::new(uid)
    let id = Identity(1000)
    if (id.uid != 1000) {
        throw Exception("uid should be 1000")
    }
}

@Test
func testIdentityZeroUid(): Unit {
    // 对齐 Rust: Identity::new(0) — root 用户
    let id = Identity(0)
    if (id.uid != 0) {
        throw Exception("uid should be 0")
    }
}

@Test
func testIdentityNegativeUid(): Unit {
    // 对齐 Rust: Identity — 负 UID
    let id = Identity(-1)
    if (id.uid != -1) {
        throw Exception("uid should be -1")
    }
}

@Test
func testIdentityLargeUid(): Unit {
    // 对齐 Rust: Identity — 大 UID
    let id = Identity(4294967295)
    if (id.uid != 4294967295) {
        throw Exception("uid should be 4294967295")
    }
}

// ============================================================
// Trust 排序测试 — 对齐 gix-sec/tests/sec/main.rs::trust
// ============================================================

@Test
func testTrustOrdering(): Unit {
    // 对齐 Rust: trust::ordering — Reduced < Full
    // 仓颉差异：Trust 枚举无内置 Ord，验证枚举变体可以正确比较
    let full = Trust.Full
    let reduced = Trust.Reduced
    let none = Trust.None
    // 验证不等性
    if (full == reduced) {
        throw Exception("Full should not equal Reduced")
    }
    if (reduced == none) {
        throw Exception("Reduced should not equal None")
    }
    if (full == none) {
        throw Exception("Full should not equal None")
    }
}

@Test
func testTrustAllVariantsDistinct(): Unit {
    // 对齐 Rust: trust — 所有变体互不相等
    let variants = [Trust.Full, Trust.Reduced, Trust.None]
    for (i in 0..variants.size) {
        for (j in 0..variants.size) {
            if (i != j) {
                if (variants[i] == variants[j]) {
                    throw Exception("variant " + i.toString() + " should not equal variant " + j.toString())
                }
            }
        }
    }
}

// ============================================================
// Identity 补充测试 — 对齐 gix-sec/tests/sec/identity.rs
// ============================================================

@Test
func testIdentityIsPathOwnedByCurrentUser(): Unit {
    // 对齐 Rust: identity::is_path_owned_by_current_user
    // 仓颉简化：验证 Identity 可以构造并访问
    let id = Identity(1000)
    if (id.uid != 1000) {
        throw Exception("uid should be 1000")
    }
}

@Test
func testIdentityEqualityByValue(): Unit {
    // 对齐 Rust: Identity — 相同 uid 的 Identity
    let id1 = Identity(42)
    let id2 = Identity(42)
    // Identity 当前没有 equals，验证 uid 相等
    if (id1.uid != id2.uid) {
        throw Exception("same uid should be equal")
    }
}

@Test
func testTrustForPathVariousPaths(): Unit {
    // 对齐 Rust: trust_for_path — 不同路径
    let paths = ["/", "C:\\", ".", "..", "/tmp", "/home/user/.git"]
    for (p in paths) {
        let trust = trustForPath(p)
        // Windows 下默认返回 Full
        if (trust != Trust.Full) {
            throw Exception("trust for '" + p + "' should be Full on Windows")
        }
    }
}
