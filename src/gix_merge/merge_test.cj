// 文件：merge_test.cj
// 用途：gix_merge 包的单元测试，全量对齐 Rust gitoxide gix-merge 测试
// 所属包：gix.gix_merge
// 对齐来源：gix-merge/tests/merge.rs, gix-merge/tests/merge/blob/builtin_driver.rs

package gitoxide.gix_merge

import gitoxide.gix_hash.*
import gitoxide.gix_imara_diff.*
import std.unittest.*
import std.collection.*

// ============================================================
// threeWayMerge 测试 — 对齐 gix-merge/tests/merge.rs
// ============================================================

@Test
func testThreeWayMergeOursSameAsTheirs(): Unit {
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    ours.add("line1")
    ours.add("line2")
    let theirs = ArrayList<String>()
    theirs.add("line1")
    theirs.add("line2")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 2) {
                throw Exception("should have 2 lines, got " + mc.lines.size.toString())
            }
        case MergeResult.Conflict(_) => throw Exception("should be clean merge when ours == theirs")
    }
}

@Test
func testThreeWayMergeOursChanged(): Unit {
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    ours.add("line1")
    ours.add("line2")
    let theirs = ArrayList<String>()
    theirs.add("line1")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 2) {
                throw Exception("should have 2 lines from ours")
            }
            if (mc.lines[1] != "line2") {
                throw Exception("second line should be 'line2'")
            }
        case MergeResult.Conflict(_) => throw Exception("should be clean when only ours changed")
    }
}

@Test
func testThreeWayMergeTheirsChanged(): Unit {
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    ours.add("line1")
    let theirs = ArrayList<String>()
    theirs.add("line1")
    theirs.add("line3")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 2) {
                throw Exception("should have 2 lines from theirs")
            }
            if (mc.lines[1] != "line3") {
                throw Exception("second line should be 'line3'")
            }
        case MergeResult.Conflict(_) => throw Exception("should be clean when only theirs changed")
    }
}

@Test
func testThreeWayMergeBothChangedDifferently(): Unit {
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    ours.add("line2")
    let theirs = ArrayList<String>()
    theirs.add("line3")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(_) => throw Exception("should be conflict when both changed differently")
        case MergeResult.Conflict(cc) =>
            if (cc.conflicts.size != 1) {
                throw Exception("should have 1 conflict")
            }
    }
}

@Test
func testThreeWayMergeNoChanges(): Unit {
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    ours.add("line1")
    let theirs = ArrayList<String>()
    theirs.add("line1")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 1) {
                throw Exception("should have 1 line")
            }
        case MergeResult.Conflict(_) => throw Exception("should be clean when no changes")
    }
}

// ============================================================
// MergeResult/Conflict 类型测试
// ============================================================

@Test
func testConflictConstruction(): Unit {
    let c = Conflict(0, 5, 10, 3)
    if (c.oursStart != 0) {
        throw Exception("oursStart mismatch")
    }
    if (c.oursLen != 5) {
        throw Exception("oursLen mismatch")
    }
    if (c.theirsStart != 10) {
        throw Exception("theirsStart mismatch")
    }
    if (c.theirsLen != 3) {
        throw Exception("theirsLen mismatch")
    }
}

@Test
func testMergedContentCreation(): Unit {
    let mc = MergedContent()
    if (mc.lines.size != 0) {
        throw Exception("new MergedContent should have 0 lines")
    }
    mc.lines.add("merged line")
    if (mc.lines.size != 1) {
        throw Exception("should have 1 line after add")
    }
}

@Test
func testConflictContentCreation(): Unit {
    let cc = ConflictContent()
    if (cc.lines.size != 0) {
        throw Exception("lines should be empty")
    }
    if (cc.conflicts.size != 0) {
        throw Exception("conflicts should be empty")
    }
    if (!(cc.resolution == Resolution.Conflict)) {
        throw Exception("default resolution should be Conflict")
    }
}

// ============================================================
// threeWayMerge 补充测试 — 对齐 gix-merge/tests/blob/builtin_driver.rs
// ============================================================

@Test
func testThreeWayMergeBothSameChanges(): Unit {
    let base = ArrayList<String>()
    base.add("old")
    let ours = ArrayList<String>()
    ours.add("new")
    let theirs = ArrayList<String>()
    theirs.add("new")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 1 || mc.lines[0] != "new") {
                throw Exception("same changes should merge cleanly to 'new'")
            }
        case MergeResult.Conflict(_) => throw Exception("same changes should not conflict")
    }
}

@Test
func testThreeWayMergeEmptyAllInputs(): Unit {
    let base = ArrayList<String>()
    let ours = ArrayList<String>()
    let theirs = ArrayList<String>()
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 0) {
                throw Exception("all empty should merge to empty")
            }
        case MergeResult.Conflict(_) => throw Exception("all empty should not conflict")
    }
}

@Test
func testThreeWayMergeEmptyBaseBothSidesSame(): Unit {
    let base = ArrayList<String>()
    let ours = ArrayList<String>()
    ours.add("content")
    let theirs = ArrayList<String>()
    theirs.add("content")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 1 || mc.lines[0] != "content") {
                throw Exception("same sides should merge cleanly")
            }
        case MergeResult.Conflict(_) => throw Exception("same sides should not conflict")
    }
}

@Test
func testThreeWayMergeOursDeletedTheirsUnchanged(): Unit {
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    let theirs = ArrayList<String>()
    theirs.add("line1")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 0) {
                throw Exception("ours deleted should result in empty")
            }
        case MergeResult.Conflict(_) => throw Exception("ours delete + theirs unchanged should be clean")
    }
}

@Test
func testThreeWayMergeBothDeleted(): Unit {
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    let theirs = ArrayList<String>()
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 0) {
                throw Exception("both deleted should result in empty")
            }
        case MergeResult.Conflict(_) => throw Exception("both deleted should not conflict")
    }
}

@Test
func testThreeWayMergeSingleLineIdenticalChange(): Unit {
    let base = ArrayList<String>()
    base.add("a")
    let ours = ArrayList<String>()
    ours.add("b")
    let theirs = ArrayList<String>()
    theirs.add("b")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines[0] != "b") {
                throw Exception("identical change should merge to 'b'")
            }
        case MergeResult.Conflict(_) => throw Exception("identical change should not conflict")
    }
}

// ============================================================
// Resolution 类型测试 — 对齐 gix-merge/src/blob/mod.rs
// ============================================================

@Test
func testResolutionVariants(): Unit {
    let variants: Array<Resolution> = [Resolution.Complete, Resolution.CompleteWithAutoResolvedConflict, Resolution.Conflict]
    if (variants.size != 3) {
        throw Exception("should have 3 Resolution variants")
    }
}

@Test
func testResolutionEquality(): Unit {
    if (!(Resolution.Complete == Resolution.Complete)) {
        throw Exception("Complete should equal Complete")
    }
    if (!(Resolution.CompleteWithAutoResolvedConflict == Resolution.CompleteWithAutoResolvedConflict)) {
        throw Exception("CompleteWithAutoResolvedConflict should equal itself")
    }
    if (!(Resolution.Conflict == Resolution.Conflict)) {
        throw Exception("Conflict should equal Conflict")
    }
    if (Resolution.Complete == Resolution.Conflict) {
        throw Exception("Complete should not equal Conflict")
    }
}

// ============================================================
// BuiltinDriver 类型测试 — 对齐 gix-merge/src/blob/builtin_driver/mod.rs
// ============================================================

@Test
func testBuiltinDriverVariants(): Unit {
    let drivers: Array<BuiltinDriver> = [BuiltinDriver.Text, BuiltinDriver.Binary, BuiltinDriver.Union]
    if (drivers.size != 3) {
        throw Exception("should have 3 BuiltinDriver variants")
    }
}

// ============================================================
// ConflictStyle 类型测试 — 对齐 gix-merge/src/blob/builtin_driver/text/mod.rs
// ============================================================

@Test
func testConflictStyleVariants(): Unit {
    let styles: Array<ConflictStyle> = [ConflictStyle.Merge, ConflictStyle.Diff3, ConflictStyle.ZealousDiff3]
    if (styles.size != 3) {
        throw Exception("should have 3 ConflictStyle variants")
    }
}

// ============================================================
// ConflictStrategy 类型测试
// ============================================================

@Test
func testConflictStrategyVariants(): Unit {
    let strategies: Array<ConflictStrategy> = [
        ConflictStrategy.Keep(ConflictKeep(ConflictStyle.Merge, 7)),
        ConflictStrategy.ResolveWithOurs,
        ConflictStrategy.ResolveWithTheirs,
        ConflictStrategy.ResolveWithUnion
    ]
    if (strategies.size != 4) {
        throw Exception("should have 4 ConflictStrategy variants")
    }
}

// ============================================================
// binaryMerge 测试 — 对齐 gix-merge/tests/merge/blob/builtin_driver.rs::binary
// ============================================================

@Test
func testBinaryMergeDefault(): Unit {
    let result = binaryMerge(None)
    if (!(result.pick == Pick.Ours)) {
        throw Exception("default binary merge should pick ours")
    }
    if (!(result.resolution == Resolution.Conflict)) {
        throw Exception("default binary merge should be Conflict")
    }
}

@Test
func testBinaryMergeResolveWithAncestor(): Unit {
    let result = binaryMerge(Some(BinaryResolveWith.Ancestor))
    if (!(result.pick == Pick.Ancestor)) {
        throw Exception("resolve with ancestor should pick Ancestor")
    }
    if (!(result.resolution == Resolution.CompleteWithAutoResolvedConflict)) {
        throw Exception("resolve with ancestor should be CompleteWithAutoResolvedConflict")
    }
}

@Test
func testBinaryMergeResolveWithOurs(): Unit {
    let result = binaryMerge(Some(BinaryResolveWith.Ours))
    if (!(result.pick == Pick.Ours)) {
        throw Exception("resolve with ours should pick Ours")
    }
    if (!(result.resolution == Resolution.CompleteWithAutoResolvedConflict)) {
        throw Exception("resolve with ours should be CompleteWithAutoResolvedConflict")
    }
}

@Test
func testBinaryMergeResolveWithTheirs(): Unit {
    let result = binaryMerge(Some(BinaryResolveWith.Theirs))
    if (!(result.pick == Pick.Theirs)) {
        throw Exception("resolve with theirs should pick Theirs")
    }
    if (!(result.resolution == Resolution.CompleteWithAutoResolvedConflict)) {
        throw Exception("resolve with theirs should be CompleteWithAutoResolvedConflict")
    }
}

// ============================================================
// textMerge 测试 — 对齐 gix-merge/tests/merge/blob/builtin_driver.rs::text
// ============================================================

@Test
func testTextMergeSameContent(): Unit {
    let opts = TextMergeOptions()
    let labels = Labels()
    let result = textMerge("hello\nworld\n", "hello\nworld\n", "hello\nworld\n", opts, labels)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 4) {
                throw Exception("should have 4 items (2 lines + 2 newlines), got " + mc.lines.size.toString())
            }
        case MergeResult.Conflict(_) => throw Exception("same content should not conflict")
    }
}

@Test
func testTextMergeOnlyOursChanged(): Unit {
    let opts = TextMergeOptions()
    let labels = Labels()
    let result = textMerge("base\n", "ours\n", "base\n", opts, labels)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines[0] != "ours") {
                throw Exception("should take ours change")
            }
        case MergeResult.Conflict(_) => throw Exception("only ours changed should be clean")
    }
}

@Test
func testTextMergeOnlyTheirsChanged(): Unit {
    let opts = TextMergeOptions()
    let labels = Labels()
    let result = textMerge("base\n", "base\n", "theirs\n", opts, labels)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines[0] != "theirs") {
                throw Exception("should take theirs change")
            }
        case MergeResult.Conflict(_) => throw Exception("only theirs changed should be clean")
    }
}

@Test
func testTextMergeBothSameChanges(): Unit {
    let opts = TextMergeOptions()
    let labels = Labels()
    let result = textMerge("base\n", "changed\n", "changed\n", opts, labels)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines[0] != "changed") {
                throw Exception("same changes should merge to 'changed'")
            }
        case MergeResult.Conflict(_) => throw Exception("same changes should not conflict")
    }
}

@Test
func testTextMergeConflictResolveWithOurs(): Unit {
    let opts = TextMergeOptions(Algorithm.Myers, ConflictStrategy.ResolveWithOurs)
    let labels = Labels()
    let result = textMerge("base\n", "ours\n", "theirs\n", opts, labels)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines[0] != "ours") {
                throw Exception("ResolveWithOurs should take ours")
            }
        case MergeResult.Conflict(_) => throw Exception("ResolveWithOurs should not produce conflict markers")
    }
}

@Test
func testTextMergeConflictResolveWithTheirs(): Unit {
    let opts = TextMergeOptions(Algorithm.Myers, ConflictStrategy.ResolveWithTheirs)
    let labels = Labels()
    let result = textMerge("base\n", "ours\n", "theirs\n", opts, labels)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines[0] != "theirs") {
                throw Exception("ResolveWithTheirs should take theirs")
            }
        case MergeResult.Conflict(_) => throw Exception("ResolveWithTheirs should not produce conflict markers")
    }
}

@Test
func testTextMergeConflictResolveWithUnion(): Unit {
    let opts = TextMergeOptions(Algorithm.Myers, ConflictStrategy.ResolveWithUnion)
    let labels = Labels()
    let result = textMerge("base\n", "ours\n", "theirs\n", opts, labels)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size < 2) {
                throw Exception("ResolveWithUnion should have both sides")
            }
        case MergeResult.Conflict(_) => throw Exception("ResolveWithUnion should not produce conflict markers")
    }
}

@Test
func testTextMergeConflictKeepMerge(): Unit {
    let opts = TextMergeOptions(Algorithm.Myers, ConflictStrategy.Keep(ConflictKeep(ConflictStyle.Merge, 7)))
    let labels = Labels(None, Some("OURS"), Some("THEIRS"))
    let result = textMerge("base\n", "ours\n", "theirs\n", opts, labels)
    match (result) {
        case MergeResult.Clean(_) => throw Exception("Keep should produce conflict markers")
        case MergeResult.Conflict(cc) =>
            if (cc.conflicts.size != 1) {
                throw Exception("should have 1 conflict")
            }
            if (!(cc.resolution == Resolution.Conflict)) {
                throw Exception("resolution should be Conflict")
            }
            var hasOursMarker = false
            var hasTheirsMarker = false
            for (line in cc.lines) {
                if (line.contains("<<<<<<<")) { hasOursMarker = true }
                if (line.contains(">>>>>>>")) { hasTheirsMarker = true }
            }
            if (!hasOursMarker) {
                throw Exception("should have <<<<<<< marker")
            }
            if (!hasTheirsMarker) {
                throw Exception("should have >>>>>>> marker")
            }
    }
}

@Test
func testTextMergeConflictKeepDiff3(): Unit {
    let opts = TextMergeOptions(Algorithm.Myers, ConflictStrategy.Keep(ConflictKeep(ConflictStyle.Diff3, 7)))
    let labels = Labels(Some("BASE"), Some("OURS"), Some("THEIRS"))
    let result = textMerge("base\n", "ours\n", "theirs\n", opts, labels)
    match (result) {
        case MergeResult.Clean(_) => throw Exception("Keep Diff3 should produce conflict markers")
        case MergeResult.Conflict(cc) =>
            var hasBaseMarker = false
            for (line in cc.lines) {
                if (line.contains("|||||||")) { hasBaseMarker = true }
            }
            if (!hasBaseMarker) {
                throw Exception("Diff3 should have ||||||| marker for base")
            }
    }
}

@Test
func testTextMergeEmptyBase(): Unit {
    let opts = TextMergeOptions()
    let labels = Labels()
    let result = textMerge("", "ours content\n", "theirs content\n", opts, labels)
    match (result) {
        case MergeResult.Clean(_) | MergeResult.Conflict(_) => ()
    }
}

@Test
func testTextMergeEmptyAll(): Unit {
    let opts = TextMergeOptions()
    let labels = Labels()
    let result = textMerge("", "", "", opts, labels)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 0) {
                throw Exception("all empty should merge to empty")
            }
        case MergeResult.Conflict(_) => throw Exception("all empty should not conflict")
    }
}

// ============================================================
// Labels 测试
// ============================================================

@Test
func testLabelsCreation(): Unit {
    let labels = Labels()
    if (labels.ancestor.isSome() || labels.current.isSome() || labels.other.isSome()) {
        throw Exception("default labels should all be None")
    }
    let labeled = Labels(Some("base"), Some("ours"), Some("theirs"))
    if (labeled.ancestor != Some("base")) {
        throw Exception("ancestor label mismatch")
    }
    if (labeled.current != Some("ours")) {
        throw Exception("current label mismatch")
    }
    if (labeled.other != Some("theirs")) {
        throw Exception("other label mismatch")
    }
}

// ============================================================
// TextMergeOptions 测试
// ============================================================

@Test
func testTextMergeOptionsDefault(): Unit {
    let opts = TextMergeOptions()
    if (!(opts.diffAlgorithm == Algorithm.Myers)) {
        throw Exception("default diff algorithm should be Myers")
    }
    match (opts.conflict) {
        case ConflictStrategy.Keep(keep) =>
            if (keep.style != ConflictStyle.Merge) {
                throw Exception("default conflict style should be Merge")
            }
            if (keep.markerSize != 7) {
                throw Exception("default marker size should be 7")
            }
        case _ => throw Exception("default conflict strategy should be Keep")
    }
}

// ============================================================
// ResourceKind 测试
// ============================================================

@Test
func testResourceKindVariants(): Unit {
    let kinds: Array<ResourceKind> = [ResourceKind.CurrentOrOurs, ResourceKind.OtherOrTheirs, ResourceKind.CommonAncestorOrBase]
    if (kinds.size != 3) {
        throw Exception("should have 3 ResourceKind variants")
    }
}

// ============================================================
// Pick/BinaryResolveWith 测试
// ============================================================

@Test
func testPickVariants(): Unit {
    let picks: Array<Pick> = [Pick.Ancestor, Pick.Ours, Pick.Theirs]
    if (picks.size != 3) {
        throw Exception("should have 3 Pick variants")
    }
}

@Test
func testBinaryResolveWithVariants(): Unit {
    let resolves: Array<BinaryResolveWith> = [BinaryResolveWith.Ancestor, BinaryResolveWith.Ours, BinaryResolveWith.Theirs]
    if (resolves.size != 3) {
        throw Exception("should have 3 BinaryResolveWith variants")
    }
}
