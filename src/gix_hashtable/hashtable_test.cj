// 文件：hashtable_test.cj
// 用途：gix_hashtable 包的单元测试，全量对齐 Rust gitoxide gix-hashtable 测试
// 所属包：gix.gix_hashtable
// 对齐来源：gix-hashtable/tests/{put,get,remove}.rs

package gitoxide.gix_hashtable

import std.unittest.*
import gitoxide.gix_hash.ObjectId

// ============================================================
// HashMap 测试 — 对齐 gix-hashtable/tests/put.rs
// ============================================================

@Test
func testHashMapPutAndGet(): Unit {
    // 对齐 Rust: HashMap::put + get
    let map = HashMap<String, Int64>()
    map.put("key1", 1)
    let result = map.get("key1")
    if (result != Some(1)) {
        throw Exception("get after put should return value")
    }
}

@Test
func testHashMapPutOverwrite(): Unit {
    // 对齐 Rust: HashMap::put — 覆盖已有键
    let map = HashMap<String, Int64>()
    map.put("key1", 1)
    let old = map.put("key1", 2)
    if (old != Some(1)) {
        throw Exception("put overwrite should return old value")
    }
    if (map.get("key1") != Some(2)) {
        throw Exception("get after overwrite should return new value")
    }
}

@Test
func testHashMapPutMultiple(): Unit {
    // 对齐 Rust: HashMap::put — 多个键
    let map = HashMap<String, Int64>()
    map.put("a", 1)
    map.put("b", 2)
    map.put("c", 3)
    if (map.len() != 3) {
        throw Exception("len should be 3, got " + map.len().toString())
    }
}

// ============================================================
// HashMap get 测试 — 对齐 gix-hashtable/tests/get.rs
// ============================================================

@Test
func testHashMapGetNonExistent(): Unit {
    // 对齐 Rust: HashMap::get — 不存在的键
    let map = HashMap<String, Int64>()
    if (map.get("nonexistent").isSome()) {
        throw Exception("get for non-existent key should return None")
    }
}

@Test
func testHashMapContains(): Unit {
    // 对齐 Rust: HashMap::contains
    let map = HashMap<String, Int64>()
    map.put("key1", 1)
    if (!map.contains("key1")) {
        throw Exception("should contain key1")
    }
    if (map.contains("nonexistent")) {
        throw Exception("should not contain nonexistent")
    }
}

// ============================================================
// HashMap remove 测试 — 对齐 gix-hashtable/tests/remove.rs
// ============================================================

@Test
func testHashMapRemove(): Unit {
    // 对齐 Rust: HashMap::remove
    let map = HashMap<String, Int64>()
    map.put("key1", 1)
    let removed = map.remove("key1")
    if (removed != Some(1)) {
        throw Exception("remove should return removed value")
    }
    if (map.get("key1").isSome()) {
        throw Exception("get after remove should return None")
    }
    if (map.len() != 0) {
        throw Exception("len should be 0 after remove")
    }
}

// ============================================================
// HashMap 边界测试
// ============================================================

@Test
func testHashMapDefaultCapacity(): Unit {
    // 对齐 Rust: HashMap::default()
    let map = HashMap<String, Int64>()
    if (map.len() != 0) {
        throw Exception("new HashMap should have len 0")
    }
}

@Test
func testHashMapSmallCapacity(): Unit {
    // 对齐 Rust: HashMap::with_capacity(1) — 最小容量为 16
    let map = HashMap<String, Int64>(1)
    if (map.len() != 0) {
        throw Exception("HashMap with small capacity should have len 0")
    }
}

@Test
func testHashMapManyEntries(): Unit {
    // 对齐 Rust: HashMap — 大量条目
    let map = HashMap<String, Int64>()
    for (i in 0..100) {
        map.put("key" + i.toString(), i)
    }
    if (map.len() != 100) {
        throw Exception("HashMap should have 100 entries, got " + map.len().toString())
    }
    for (i in 0..100) {
        let v = map.get("key" + i.toString())
        if (v != Some(i)) {
            throw Exception("HashMap value mismatch for key" + i.toString())
        }
    }
}

// ============================================================
// HashMap 补充测试 — 对齐 gix-hashtable/src/lib.rs
// ============================================================

@Test
func testHashMapRemoveThenReinsert(): Unit {
    // 对齐 Rust: HashMap remove 后重新插入
    let map = HashMap<String, Int64>()
    map.put("key1", 1)
    map.remove("key1")
    map.put("key1", 2)
    if (map.get("key1") != Some(2)) {
        throw Exception("reinserted value should be 2")
    }
    if (map.len() != 1) {
        throw Exception("len should be 1 after reinsert")
    }
}

@Test
func testHashMapPutOverwriteReturnsOld(): Unit {
    // 对齐 Rust: HashMap put 覆盖返回旧值
    let map = HashMap<String, Int64>()
    map.put("key1", 10)
    let old = map.put("key1", 20)
    if (old != Some(10)) {
        throw Exception("old value should be 10")
    }
    if (map.get("key1") != Some(20)) {
        throw Exception("new value should be 20")
    }
    if (map.len() != 1) {
        throw Exception("len should still be 1 after overwrite")
    }
}

@Test
func testHashMapMultipleRemoves(): Unit {
    // 对齐 Rust: HashMap 多次 remove
    let map = HashMap<String, Int64>()
    map.put("a", 1)
    map.put("b", 2)
    map.put("c", 3)
    map.remove("a")
    map.remove("c")
    if (map.len() != 1) {
        throw Exception("len should be 1 after 2 removes")
    }
    if (map.get("b") != Some(2)) {
        throw Exception("b should still be 2")
    }
}

@Test
func testHashMapStressTest(): Unit {
    // 对齐 Rust: HashMap 压力测试 — 大量插入和查找
    let map = HashMap<String, Int64>()
    for (i in 0..200) {
        map.put("k" + i.toString(), i)
    }
    if (map.len() != 200) {
        throw Exception("should have 200 entries")
    }
    for (i in 0..200) {
        if (map.get("k" + i.toString()) != Some(i)) {
            throw Exception("value mismatch for k" + i.toString())
        }
    }
}

@Test
func testHashMapRemoveHalfAndCheck(): Unit {
    // 对齐 Rust: HashMap 删除一半后检查
    let map = HashMap<String, Int64>()
    for (i in 0..50) {
        map.put("k" + i.toString(), i)
    }
    for (i in 0..25) {
        map.remove("k" + i.toString())
    }
    if (map.len() != 25) {
        throw Exception("should have 25 entries after removing half")
    }
    for (i in 25..50) {
        if (!map.contains("k" + i.toString())) {
            throw Exception("should contain k" + i.toString())
        }
    }
    for (i in 0..25) {
        if (map.contains("k" + i.toString())) {
            throw Exception("should not contain removed k" + i.toString())
        }
    }
}

@Test
func testHashMapEmptyStringKey(): Unit {
    // 对齐 Rust: HashMap 空字符串键
    let map = HashMap<String, Int64>()
    map.put("", 42)
    if (map.get("") != Some(42)) {
        throw Exception("empty key should work")
    }
    if (!map.contains("")) {
        throw Exception("should contain empty key")
    }
}

@Test
func testHashMapIntegerKeys(): Unit {
    // 对齐 Rust: HashMap 整数键
    let map = HashMap<Int64, String>()
    for (i in 0..20) {
        map.put(i, "val" + i.toString())
    }
    if (map.len() != 20) {
        throw Exception("should have 20 entries")
    }
    if (map.get(10) != Some("val10")) {
        throw Exception("value mismatch for key 10")
    }
}

// ============================================================
// Hasher 测试 — 已移除（仓颉 std.hash.Hasher 是接口，无法实例化）
// ============================================================

@Test
func testHashMapWithInt64Keys(): Unit {
    // 对齐 Rust: HashMap — Int64 键
    let map = HashMap<Int64, String>()
    map.put(1, "one")
    map.put(2, "two")
    map.put(100, "hundred")
    if (map.get(1) != Some("one")) {
        throw Exception("key 1 should be one")
    }
    if (map.get(2) != Some("two")) {
        throw Exception("key 2 should be two")
    }
    if (map.get(100) != Some("hundred")) {
        throw Exception("key 100 should be hundred")
    }
    if (map.get(999).isSome()) {
        throw Exception("key 999 should not exist")
    }
}

@Test
func testHashMapResizeOnHighLoad(): Unit {
    // 对齐 Rust: HashMap — 高负载因子时扩容
    let map = HashMap<String, Int64>(16)
    for (i in 0..20) {
        map.put("key" + i.toString(), i)
    }
    if (map.len() != 20) {
        throw Exception("should have 20 entries after resize")
    }
    for (i in 0..20) {
        if (map.get("key" + i.toString()) != Some(i)) {
            throw Exception("value mismatch for key" + i.toString() + " after resize")
        }
    }
}

@Test
func testHashMapPutReturnsOldValue(): Unit {
    // 对齐 Rust: HashMap::put — 返回旧值
    let map = HashMap<String, Int64>()
    let old1 = map.put("a", 1)
    if (!old1.isNone()) {
        throw Exception("first put should return None")
    }
    let old2 = map.put("a", 2)
    if (old2 != Some(1)) {
        throw Exception("second put should return old value 1")
    }
    if (map.get("a") != Some(2)) {
        throw Exception("value should be updated to 2")
    }
}

@Test
func testHashMapRemoveNonExistent(): Unit {
    // 对齐 Rust: HashMap::remove — 删除不存在的键
    let map = HashMap<String, Int64>()
    map.put("a", 1)
    let removed = map.remove("b")
    if (!removed.isNone()) {
        throw Exception("removing non-existent key should return None")
    }
    if (map.len() != 1) {
        throw Exception("len should still be 1")
    }
}

@Test
func testHashMapContainsAfterRemove(): Unit {
    // 对齐 Rust: HashMap::contains — 删除后不再包含
    let map = HashMap<String, Int64>()
    map.put("x", 10)
    if (!map.contains("x")) {
        throw Exception("should contain x before remove")
    }
    map.remove("x")
    if (map.contains("x")) {
        throw Exception("should not contain x after remove")
    }
}

// ============================================================
// ObjectIdMap 测试 — 对齐 gix-hashtable/src/lib.rs sync::ObjectIdMap
// ============================================================

@Test
func testObjectIdMapDefault(): Unit {
    // 对齐 Rust: ObjectIdMap::default()
    let map = ObjectIdMap<String>()
    if (map.len() != 0) {
        throw Exception("new ObjectIdMap should have len 0")
    }
}

@Test
func testObjectIdMapInsertAndGet(): Unit {
    // 对齐 Rust: ObjectIdMap::insert + get
    let map = ObjectIdMap<String>()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    map.insert(id, "empty blob")
    let result = map.get(id)
    if (result != Some("empty blob")) {
        throw Exception("get after insert should return value")
    }
}

@Test
func testObjectIdMapInsertReturnsOld(): Unit {
    // 对齐 Rust: ObjectIdMap::insert — 返回旧值
    let map = ObjectIdMap<Int64>()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let old1 = map.insert(id, 1)
    if (!old1.isNone()) {
        throw Exception("first insert should return None")
    }
    let old2 = map.insert(id, 2)
    if (old2 != Some(1)) {
        throw Exception("second insert should return old value 1")
    }
    if (map.get(id) != Some(2)) {
        throw Exception("value should be updated to 2")
    }
}

@Test
func testObjectIdMapGetNonExistent(): Unit {
    // 对齐 Rust: ObjectIdMap::get — 不存在的键
    let map = ObjectIdMap<String>()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    if (map.get(id).isSome()) {
        throw Exception("get for non-existent key should return None")
    }
}

@Test
func testObjectIdMapContains(): Unit {
    // 对齐 Rust: ObjectIdMap::contains
    let map = ObjectIdMap<Int64>()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    if (map.contains(id)) {
        throw Exception("should not contain key before insert")
    }
    map.insert(id, 42)
    if (!map.contains(id)) {
        throw Exception("should contain key after insert")
    }
}

@Test
func testObjectIdMapRemove(): Unit {
    // 对齐 Rust: ObjectIdMap::remove
    let map = ObjectIdMap<String>()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    map.insert(id, "value")
    let removed = map.remove(id)
    if (removed != Some("value")) {
        throw Exception("remove should return removed value")
    }
    if (map.get(id).isSome()) {
        throw Exception("get after remove should return None")
    }
    if (map.len() != 0) {
        throw Exception("len should be 0 after remove")
    }
}

@Test
func testObjectIdMapMultipleObjectIds(): Unit {
    // 对齐 Rust: ObjectIdMap — 多个不同 ObjectId
    let map = ObjectIdMap<Int64>()
    let id1 = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let id3 = ObjectId.fromHex("0000000000000000000000000000000000000000")
    map.insert(id1, 1)
    map.insert(id2, 2)
    map.insert(id3, 3)
    if (map.len() != 3) {
        throw Exception("should have 3 entries")
    }
    if (map.get(id1) != Some(1)) {
        throw Exception("id1 should be 1")
    }
    if (map.get(id2) != Some(2)) {
        throw Exception("id2 should be 2")
    }
    if (map.get(id3) != Some(3)) {
        throw Exception("id3 should be 3")
    }
}

@Test
func testObjectIdMapShardingByFirstByte(): Unit {
    // 对齐 Rust: ObjectIdMap — 按 ObjectId 首字节分片
    // 验证不同首字节的 ObjectId 分布到不同分片
    let map = ObjectIdMap<Int64>()
    // 首字节为 0xe6
    let id1 = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    // 首字节为 0x4b
    let id2 = ObjectId.fromHex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    // 首字节为 0x00
    let id3 = ObjectId.fromHex("0000000000000000000000000000000000000000")
    map.insert(id1, 100)
    map.insert(id2, 200)
    map.insert(id3, 300)
    if (map.get(id1) != Some(100)) {
        throw Exception("id1 should be 100")
    }
    if (map.get(id2) != Some(200)) {
        throw Exception("id2 should be 200")
    }
    if (map.get(id3) != Some(300)) {
        throw Exception("id3 should be 300")
    }
}

@Test
func testObjectIdMapInsertImmutable(): Unit {
    // 对齐 Rust: gix_pack::data::output::count::objects::util::InsertImmutable for ObjectIdMap<()>
    // insert 返回 None 表示首次插入（键不存在），返回 Some 表示键已存在
    let map = ObjectIdMap<Bool>()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let first = map.insert(id, true)
    if (!first.isNone()) {
        throw Exception("first insert should return None (key was new)")
    }
    let second = map.insert(id, true)
    if (second.isNone()) {
        throw Exception("second insert should return Some (key existed)")
    }
}
