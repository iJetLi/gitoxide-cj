package gitoxide.gix_negotiate

import std.unittest.*
import gitoxide.gix_hash.*

@Test
func testNegotiatorCreation(): Unit {
    // 对齐 Rust: gix-negotiate/tests/baseline/mod.rs — Negotiator::default()
    let n = Negotiator()
    if (n.known.size != 0) {
        throw Exception("new negotiator should have 0 known commits")
    }
}

@Test
func testNegotiatorAddKnown(): Unit {
    // 对齐 Rust: gix-negotiate/tests/baseline/mod.rs — Negotiator::add_tip / known_common
    let n = Negotiator()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    n.addKnown(id)
    if (n.known.size != 1) {
        throw Exception("should have 1 known commit after add")
    }
}

@Test
func testNegotiatorIsKnown(): Unit {
    // 对齐 Rust: gix-negotiate/tests/baseline/mod.rs — Negotiator trait 方法间接测试
    let n = Negotiator()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    if (n.isKnown(id)) {
        throw Exception("unknown commit should not be known")
    }
    n.addKnown(id)
    if (!n.isKnown(id)) {
        throw Exception("added commit should be known")
    }
}

@Test
func testNegotiatorCommon(): Unit {
    // 对齐 Rust: gix-negotiate/tests/baseline/mod.rs — Negotiator::in_common_with_remote
    let n = Negotiator()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    n.addKnown(id)
    let common = n.common()
    if (common.size != 1) {
        throw Exception("common should have 1 entry")
    }
}

@Test
func testWindowSizeInitialValue(): Unit {
    // 对齐 Rust: gix-negotiate/tests/window_size.rs::initial_value_without_previous_window_size
    if (windowSize(false, None) != 16) {
        throw Exception("initial value should be 16")
    }
    if (windowSize(true, None) != 16) {
        throw Exception("initial value should be 16 for stateless too")
    }
}

@Test
func testWindowSizeStateless(): Unit {
    // 对齐 Rust: gix-negotiate/tests/window_size.rs::transport_is_stateless
    var prev: ?Int64 = Some(16)
    let expected: Array<Int64> = [32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384]
    for (i in 0..expected.size) {
        let sz = windowSize(true, prev)
        if (sz != expected[i]) {
            throw Exception(
                "stateless step " + i.toString() + " should be " + expected[i].toString() + ", got " + sz.toString())
        }
        prev = Some(sz)
    }
    let afterLarge = windowSize(true, prev)
    if (afterLarge != Int64(16384) * 11 / 10) {
        throw Exception("after 16384 should be 16384*11/10, got " + afterLarge.toString())
    }
}

@Test
func testWindowSizeNotStateless(): Unit {
    // 对齐 Rust: gix-negotiate/tests/window_size.rs::transport_is_not_stateless
    var prev: ?Int64 = Some(16)
    let sz1 = windowSize(false, prev)
    if (sz1 != 32) {
        throw Exception("16->32, got " + sz1.toString())
    }
    prev = Some(sz1)
    let sz2 = windowSize(false, prev)
    if (sz2 != 64) {
        throw Exception("32->64, got " + sz2.toString())
    }
    prev = Some(sz2)
    let sz3 = windowSize(false, prev)
    if (sz3 != 96) {
        throw Exception("64->96, got " + sz3.toString())
    }
    prev = Some(sz3)
    let sz4 = windowSize(false, prev)
    if (sz4 != 128) {
        throw Exception("96->128, got " + sz4.toString())
    }
}
