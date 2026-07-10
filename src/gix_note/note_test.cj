// 文件：note_test.cj
// 用途：gix_note 包的单元测试，全量对齐 Rust gitoxide gix-note 测试
// 所属包：gix.gix_note
// 对齐来源：gix-note/tests/note.rs

package gitoxide.gix_note

import gitoxide.gix_hash.*
import std.unittest.*

// ============================================================
// Note 测试
// ============================================================

@Test
func testNoteConstruction(): Unit {
    // 对齐 Rust: Note construction
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let note = Note(id, "this is a note")
    if (note.commitId.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("commitId mismatch")
    }
    if (note.message != "this is a note") {
        throw Exception("message mismatch")
    }
}

// ============================================================
// NoteMap 测试 — 对齐 gix-note/tests/note_map.rs
// ============================================================

@Test
func testNoteMapCreation(): Unit {
    // 对齐 Rust: NoteMap::new()
    let map = NoteMap()
    if (map.notes.size != 0) {
        throw Exception("new NoteMap should be empty")
    }
}

@Test
func testNoteMapSetAndGet(): Unit {
    // 对齐 Rust: NoteMap set → get
    let map = NoteMap()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let noteId = ObjectId.fromHex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    map.set(id, noteId)
    let result = map.get(id)
    if (result.isNone()) {
        throw Exception("should find note after set")
    }
    if (result.getOrThrow().toHexString() != "4b825dc642cb6eb9a060e54bf8d69288fbee4904") {
        throw Exception("note id mismatch")
    }
}

@Test
func testNoteMapGetNonExistent(): Unit {
    // 对齐 Rust: NoteMap get — non-existent
    let map = NoteMap()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    if (!map.get(id).isNone()) {
        throw Exception("should return None for non-existent")
    }
}

@Test
func testNoteMapRemove(): Unit {
    // 对齐 Rust: NoteMap remove
    let map = NoteMap()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let noteId = ObjectId.fromHex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    map.set(id, noteId)
    map.remove(id)
    if (!map.get(id).isNone()) {
        throw Exception("should return None after remove")
    }
}

@Test
func testNoteMapOverwrite(): Unit {
    // 对齐 Rust: NoteMap set overwrites existing
    let map = NoteMap()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let noteId1 = ObjectId.fromHex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let noteId2 = ObjectId.fromHex("0000000000000000000000000000000000000000")
    map.set(id, noteId1)
    map.set(id, noteId2)
    if (map.get(id).getOrThrow().toHexString() != "0000000000000000000000000000000000000000") {
        throw Exception("should be overwritten")
    }
}

// ============================================================
// NoteMap 补充测试 — 对齐 gix-note/src/lib.rs
// ============================================================

@Test
func testNoteMapMultipleNotes(): Unit {
    // 对齐 Rust: NoteMap with multiple notes
    let map = NoteMap()
    let id1 = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let noteId1 = ObjectId.fromHex("ffa700b4aca13b80cb6b98a078e7c96804f8e0ec")
    let noteId2 = ObjectId.fromHex("9556057aee5abb06912922e9f26c46386a816822")
    map.set(id1, noteId1)
    map.set(id2, noteId2)
    if (map.get(id1).getOrThrow().toHexString() != "ffa700b4aca13b80cb6b98a078e7c96804f8e0ec") {
        throw Exception("note id1 mismatch")
    }
    if (map.get(id2).getOrThrow().toHexString() != "9556057aee5abb06912922e9f26c46386a816822") {
        throw Exception("note id2 mismatch")
    }
}

@Test
func testNoteMapRemoveNonExistent(): Unit {
    // 对齐 Rust: NoteMap remove non-existent key
    let map = NoteMap()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    map.remove(id)
    // 不应崩溃
}

@Test
func testNoteMapSetRemoveSet(): Unit {
    // 对齐 Rust: NoteMap set → remove → set
    let map = NoteMap()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let noteId1 = ObjectId.fromHex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let noteId2 = ObjectId.fromHex("ffa700b4aca13b80cb6b98a078e7c96804f8e0ec")
    map.set(id, noteId1)
    map.remove(id)
    map.set(id, noteId2)
    if (map.get(id).getOrThrow().toHexString() != "ffa700b4aca13b80cb6b98a078e7c96804f8e0ec") {
        throw Exception("should have noteId2 after re-set")
    }
}

@Test
func testNoteConstructionWithDifferentIds(): Unit {
    // 对齐 Rust: Note construction with different commit IDs
    let id1 = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let note1 = Note(id1, "note for commit 1")
    let note2 = Note(id2, "note for commit 2")
    if (note1.commitId.toHexString() == note2.commitId.toHexString()) {
        throw Exception("different notes should have different commitIds")
    }
    if (note1.message == note2.message) {
        throw Exception("different notes should have different messages")
    }
}

@Test
func testNoteEmptyMessage(): Unit {
    // 对齐 Rust: Note with empty message
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let note = Note(id, "")
    if (note.message.size != 0) {
        throw Exception("empty message should have size 0")
    }
}
