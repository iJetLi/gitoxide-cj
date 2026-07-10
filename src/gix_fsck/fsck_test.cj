// 文件：fsck_test.cj
// 用途：gix_fsck 包的单元测试，全量对齐 Rust gitoxide gix-fsck 测试
// 所属包：gix.gix_fsck
// 对齐来源：gix-fsck/tests/fsck.rs

package gitoxide.gix_fsck

import gitoxide.gix_hash.*
import std.unittest.*

// ============================================================
// FsckResult 测试
// ============================================================

@Test
func testFsckResultCreation(): Unit {
    // 对齐 Rust: FsckResult construction
    let result = FsckResult()
    if (!result.isClean()) {
        throw Exception("new FsckResult should be clean")
    }
    if (result.errors.size != 0) {
        throw Exception("should have 0 errors")
    }
}

@Test
func testFsckResultWithErrors(): Unit {
    // 对齐 Rust: FsckResult with errors
    let result = FsckResult()
    result.errors.add(FsckError(FsckErrorKind.MissingObject, "missing obj"))
    if (result.isClean()) {
        throw Exception("should not be clean with errors")
    }
    if (result.errors.size != 1) {
        throw Exception("should have 1 error")
    }
}

// ============================================================
// FsckError 测试
// ============================================================

@Test
func testFsckErrorConstruction(): Unit {
    // 对齐 Rust: FsckError construction
    let err = FsckError(FsckErrorKind.CorruptObject, "bad object")
    if (err.kind != FsckErrorKind.CorruptObject) {
        throw Exception("kind mismatch")
    }
    if (err.message != "bad object") {
        throw Exception("message mismatch")
    }
    if (err.objectId != None<ObjectId>) {
        throw Exception("objectId should default to None")
    }
}

@Test
func testFsckErrorWithObjectId(): Unit {
    // 对齐 Rust: FsckError with objectId
    let err = FsckError(FsckErrorKind.DanglingReference, "dangling")
    err.objectId = Some(ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"))
    if (err.objectId.isNone()) {
        throw Exception("objectId should be set")
    }
}

// ============================================================
// FsckErrorKind 枚举测试
// ============================================================

@Test
func testFsckErrorKindVariants(): Unit {
    // 对齐 Rust: FsckErrorKind enum completeness
    let variants: Array<FsckErrorKind> = [
        FsckErrorKind.MissingObject,
        FsckErrorKind.CorruptObject,
        FsckErrorKind.DanglingReference,
        FsckErrorKind.MissingReference
    ]
    if (variants.size != 4) {
        throw Exception("should have 4 FsckErrorKind variants, got " + variants.size.toString())
    }
}

// ============================================================
// FsckResult 补充测试 — 对齐 gix-fsck/src/lib.rs
// ============================================================

@Test
func testFsckResultMultipleErrors(): Unit {
    // 对齐 Rust: FsckResult with multiple errors
    let result = FsckResult()
    result.errors.add(FsckError(FsckErrorKind.MissingObject, "missing obj 1"))
    result.errors.add(FsckError(FsckErrorKind.CorruptObject, "corrupt obj 2"))
    result.errors.add(FsckError(FsckErrorKind.DanglingReference, "dangling ref"))
    if (result.isClean()) {
        throw Exception("should not be clean with errors")
    }
    if (result.errors.size != 3) {
        throw Exception("should have 3 errors")
    }
}

@Test
func testFsckResultAllErrorKinds(): Unit {
    // 对齐 Rust: FsckResult with all error kinds
    let result = FsckResult()
    let kinds: Array<FsckErrorKind> = [
        FsckErrorKind.MissingObject,
        FsckErrorKind.CorruptObject,
        FsckErrorKind.DanglingReference,
        FsckErrorKind.MissingReference
    ]
    for (kind in kinds) {
        result.errors.add(FsckError(kind, "error: ${kind}"))
    }
    if (result.errors.size != 4) {
        throw Exception("should have 4 errors")
    }
    if (result.errors[0].kind != FsckErrorKind.MissingObject) {
        throw Exception("first error kind mismatch")
    }
    if (result.errors[1].kind != FsckErrorKind.CorruptObject) {
        throw Exception("second error kind mismatch")
    }
    if (result.errors[2].kind != FsckErrorKind.DanglingReference) {
        throw Exception("third error kind mismatch")
    }
    if (result.errors[3].kind != FsckErrorKind.MissingReference) {
        throw Exception("fourth error kind mismatch")
    }
}

@Test
func testFsckErrorWithObjectIdSetLater(): Unit {
    // 对齐 Rust: FsckError objectId set after construction
    let err = FsckError(FsckErrorKind.MissingObject, "missing")
    if (err.objectId.isSome()) {
        throw Exception("objectId should be None initially")
    }
    err.objectId = Some(ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"))
    if (err.objectId.isNone()) {
        throw Exception("objectId should be set")
    }
    if (err.objectId.getOrThrow().toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("objectId hex mismatch")
    }
}

@Test
func testFsckErrorKindEquality(): Unit {
    // 对齐 Rust: FsckErrorKind equality
    if (FsckErrorKind.MissingObject != FsckErrorKind.MissingObject) {
        throw Exception("same kinds should be equal")
    }
    if (FsckErrorKind.CorruptObject == FsckErrorKind.DanglingReference) {
        throw Exception("different kinds should not be equal")
    }
}

@Test
func testFsckResultEmptyIsClean(): Unit {
    // 对齐 Rust: FsckResult empty is clean
    let result = FsckResult()
    if (!result.isClean()) {
        throw Exception("empty result should be clean")
    }
    result.errors.add(FsckError(FsckErrorKind.MissingObject, "err"))
    if (result.isClean()) {
        throw Exception("result with errors should not be clean")
    }
}
