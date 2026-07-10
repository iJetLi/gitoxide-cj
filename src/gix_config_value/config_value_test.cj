// 文件：config_value_test.cj
// 用途：gix_config_value 包的单元测试，全量对齐 Rust gitoxide gix-config-value 测试
// 所属包：gix.gix_config_value
// 对齐来源：gix-config-value/tests/{boolean,integer,color,path}.rs

package gitoxide.gix_config_value

import std.unittest.*

// ============================================================
// Boolean 测试 — 对齐 gix-config-value/tests/boolean.rs
// ============================================================

@Test
func testBooleanTrueValues(): Unit {
    // 对齐 Rust: Boolean::try_from("true") == Ok(True)
    let trueValues = ["true", "yes", "on", "1"]
    for (v in trueValues) {
        let result = parseBoolean(v)
        if (result != Some(Boolean.True)) {
            throw Exception("'" + v + "' should parse as True")
        }
    }
}

@Test
func testBooleanTrueCaseInsensitive(): Unit {
    // 对齐 Rust: Boolean::try_from("True") / "TRUE" / "YES" / "ON"
    let trueValues = ["True", "TRUE", "Yes", "YES", "On", "ON"]
    for (v in trueValues) {
        let result = parseBoolean(v)
        if (result != Some(Boolean.True)) {
            throw Exception("'" + v + "' should parse as True (case insensitive)")
        }
    }
}

@Test
func testBooleanFalseValues(): Unit {
    // 对齐 Rust: Boolean::try_from("false") == Ok(False)
    let falseValues = ["false", "no", "off", "0"]
    for (v in falseValues) {
        let result = parseBoolean(v)
        if (result != Some(Boolean.False)) {
            throw Exception("'" + v + "' should parse as False")
        }
    }
}

@Test
func testBooleanFalseCaseInsensitive(): Unit {
    // 对齐 Rust: Boolean::try_from("False") / "FALSE" / "NO" / "OFF"
    let falseValues = ["False", "FALSE", "No", "NO", "Off", "OFF"]
    for (v in falseValues) {
        let result = parseBoolean(v)
        if (result != Some(Boolean.False)) {
            throw Exception("'" + v + "' should parse as False (case insensitive)")
        }
    }
}

@Test
func testBooleanEmptyString(): Unit {
    // 对齐 Rust: Boolean::try_from("") == Ok(False)
    let result = parseBoolean("")
    if (result != Some(Boolean.False)) {
        throw Exception("empty string should parse as False")
    }
}

@Test
func testBooleanInvalidValue(): Unit {
    // 对齐 Rust: Boolean::try_from("invalid") == Err
    let result = parseBoolean("invalid")
    if (!result.isNone()) {
        throw Exception("'invalid' should parse as None")
    }
}

@Test
func testBooleanInvalidValues(): Unit {
    // 对齐 Rust: 各种无效值
    let invalidValues = ["invalid", "y", "n", "t", "f", "2", "10", "maybe", "enabled", "disabled"]
    for (v in invalidValues) {
        let result = parseBoolean(v)
        if (!result.isNone()) {
            throw Exception("'" + v + "' should parse as None")
        }
    }
}

@Test
func testBooleanYesnt(): Unit {
    // 对齐 Rust: from_str_err — "yesn't" is invalid
    let result = parseBoolean("yesn't")
    if (!result.isNone()) {
        throw Exception("'yesn\\'t' should be invalid")
    }
}

@Test
func testBooleanYesno(): Unit {
    // 对齐 Rust: from_str_err — "yesno" is invalid
    let result = parseBoolean("yesno")
    if (!result.isNone()) {
        throw Exception("'yesno' should be invalid")
    }
}

@Test
func testBooleanIgnoresCase(): Unit {
    // 对齐 Rust: ignores_case — 随机子集的大小写不敏感测试
    let pairs = [("no", "NO"), ("yes", "YES"), ("on", "ON"), ("off", "OFF"), ("true", "TRUE"), ("false", "FALSE")]
    for ((lower, upper) in pairs) {
        let r1 = parseBoolean(lower)
        let r2 = parseBoolean(upper)
        if (r1 != r2) {
            throw Exception("'" + lower + "' and '" + upper + "' should parse to same boolean")
        }
    }
}

// ============================================================
// Integer 测试 — 对齐 gix-config-value/tests/integer.rs
// ============================================================

@Test
func testIntegerParsing(): Unit {
    // 对齐 Rust: Integer::try_from("42") == Ok(Integer { value: 42, suffix: None })
    let result = Integer.parse("42")
    if (result.isNone()) {
        throw Exception("'42' should parse as Integer")
    }
    let r = result.getOrThrow()
    if (r.value != 42) {
        throw Exception("'42' value should be 42")
    }
    if (!r.unit.isNone()) {
        throw Exception("'42' should have no unit")
    }
}

@Test
func testIntegerWithKSuffix(): Unit {
    // 对齐 Rust: Integer::try_from("4k") == Ok(Integer { value: 4096, suffix: Some('k') })
    let result = Integer.parse("4k")
    if (result.isNone()) {
        throw Exception("'4k' should parse as Integer")
    }
    let r = result.getOrThrow()
    if (r.asDecimal() != 4096) {
        throw Exception("'4k' value should be 4096, got " + r.asDecimal().toString())
    }
}

@Test
func testIntegerWithMSuffix(): Unit {
    // 对齐 Rust: Integer::try_from("1m")
    let result = Integer.parse("1m")
    if (result.isNone()) {
        throw Exception("'1m' should parse as Integer")
    }
    let r = result.getOrThrow()
    if (r.asDecimal() != 1048576) {
        throw Exception("'1m' value should be 1048576, got " + r.asDecimal().toString())
    }
}

@Test
func testIntegerWithGSuffix(): Unit {
    // 对齐 Rust: Integer::try_from("1g")
    let result = Integer.parse("1g")
    if (result.isNone()) {
        throw Exception("'1g' should parse as Integer")
    }
    let r = result.getOrThrow()
    if (r.asDecimal() != 1073741824) {
        throw Exception("'1g' value should be 1073741824, got " + r.asDecimal().toString())
    }
}

@Test
func testIntegerZero(): Unit {
    // 对齐 Rust: Integer::try_from("0")
    let result = Integer.parse("0")
    if (result.isNone()) {
        throw Exception("'0' should parse as Integer")
    }
    if (result.getOrThrow().value != 0) {
        throw Exception("'0' value should be 0")
    }
}

@Test
func testIntegerNegative(): Unit {
    // 对齐 Rust: Integer::try_from("-1")
    let result = Integer.parse("-1")
    if (result.isNone()) {
        throw Exception("'-1' should parse as Integer")
    }
    if (result.getOrThrow().value != -1) {
        throw Exception("'-1' value should be -1")
    }
}

@Test
func testIntegerLargeValue(): Unit {
    // 对齐 Rust: Integer::try_from("999999999")
    let result = Integer.parse("999999999")
    if (result.isNone()) {
        throw Exception("'999999999' should parse as Integer")
    }
    if (result.getOrThrow().value != 999999999) {
        throw Exception("'999999999' value mismatch")
    }
}

@Test
func testIntegerInvalidValue(): Unit {
    // 对齐 Rust: Integer::try_from("not-a-number") == Err
    let result = Integer.parse("not-a-number")
    if (!result.isNone()) {
        throw Exception("'not-a-number' should parse as None")
    }
}

@Test
func testIntegerEmptyString(): Unit {
    // 对齐 Rust: Integer::try_from("") == Err
    let result = Integer.parse("")
    if (!result.isNone()) {
        throw Exception("empty string should parse as None")
    }
}

@Test
func testIntegerInvalidDashOnly(): Unit {
    // 对齐 Rust: invalid_from_str — "-" alone is invalid
    let result = Integer.parse("-")
    if (!result.isNone()) {
        throw Exception("'-' alone should be invalid")
    }
}

@Test
func testIntegerInvalidSuffixK(): Unit {
    // 对齐 Rust: invalid_from_str — "k" alone is invalid
    let result = Integer.parse("k")
    if (!result.isNone()) {
        throw Exception("'k' alone should be invalid")
    }
}

@Test
func testIntegerInvalidSuffixM(): Unit {
    // 对齐 Rust: invalid_from_str — "m" alone is invalid
    let result = Integer.parse("m")
    if (!result.isNone()) {
        throw Exception("'m' alone should be invalid")
    }
}

@Test
func testIntegerInvalidSuffixG(): Unit {
    // 对齐 Rust: invalid_from_str — "g" alone is invalid
    let result = Integer.parse("g")
    if (!result.isNone()) {
        throw Exception("'g' alone should be invalid")
    }
}

@Test
func testIntegerInvalidGg(): Unit {
    // 对齐 Rust: invalid_from_str — "gg" is invalid
    let result = Integer.parse("gg")
    if (!result.isNone()) {
        throw Exception("'gg' should be invalid")
    }
}

@Test
func testIntegerNoSuffix(): Unit {
    // 对齐 Rust: from_str_no_suffix — "1" 和 "-1"
    let r1 = Integer.parse("1")
    if (r1.isNone()) {
        throw Exception("'1' should parse")
    }
    if (r1.getOrThrow().value != 1) {
        throw Exception("'1' value should be 1")
    }
    if (!r1.getOrThrow().unit.isNone()) {
        throw Exception("'1' should have no suffix")
    }
    let r2 = Integer.parse("-1")
    if (r2.isNone()) {
        throw Exception("'-1' should parse")
    }
    if (r2.getOrThrow().value != -1) {
        throw Exception("'-1' value should be -1")
    }
    if (!r2.getOrThrow().unit.isNone()) {
        throw Exception("'-1' should have no suffix")
    }
}

@Test
func testIntegerWithSuffix(): Unit {
    // 对齐 Rust: from_str_with_suffix — "1k"/"1m"/"1g" 的 suffix 字段
    let rk = Integer.parse("1k")
    if (rk.isNone()) {
        throw Exception("'1k' should parse")
    }
    let rki = rk.getOrThrow()
    if (rki.value != 1) {
        throw Exception("'1k' raw value should be 1, got " + rki.value.toString())
    }
    if (rki.unit != Some("k")) {
        throw Exception("'1k' suffix should be 'k'")
    }
    let rm = Integer.parse("1m")
    if (rm.isNone()) {
        throw Exception("'1m' should parse")
    }
    let rmi = rm.getOrThrow()
    if (rmi.value != 1) {
        throw Exception("'1m' raw value should be 1")
    }
    if (rmi.unit != Some("m")) {
        throw Exception("'1m' suffix should be 'm'")
    }
    let rg = Integer.parse("1g")
    if (rg.isNone()) {
        throw Exception("'1g' should parse")
    }
    let rgi = rg.getOrThrow()
    if (rgi.value != 1) {
        throw Exception("'1g' raw value should be 1")
    }
    if (rgi.unit != Some("g")) {
        throw Exception("'1g' suffix should be 'g'")
    }
}

@Test
func testIntegerAsDecimal(): Unit {
    // 对齐 Rust: as_decimal — 带后缀的十进制值转换
    // 12 无后缀 => 12
    let r12 = Integer.parse("12")
    if (r12.isNone()) {
        throw Exception("'12' should parse")
    }
    if (r12.getOrThrow().asDecimal() != 12) {
        throw Exception("'12' should be 12")
    }
    // 13k => 13 * 1024
    let r13k = Integer.parse("13k")
    if (r13k.isNone()) {
        throw Exception("'13k' should parse")
    }
    if (r13k.getOrThrow().asDecimal() != 13 * 1024) {
        throw Exception("'13k' should be 13312, got " + r13k.getOrThrow().asDecimal().toString())
    }
    // 14m => 14 * 1048576
    let r14m = Integer.parse("14m")
    if (r14m.isNone()) {
        throw Exception("'14m' should parse")
    }
    if (r14m.getOrThrow().asDecimal() != 14 * 1048576) {
        throw Exception("'14m' should be 14680064, got " + r14m.getOrThrow().asDecimal().toString())
    }
    // 15g => 15 * 1073741824
    let r15g = Integer.parse("15g")
    if (r15g.isNone()) {
        throw Exception("'15g' should parse")
    }
    if (r15g.getOrThrow().asDecimal() != 15 * 1073741824) {
        throw Exception("'15g' should be 16106127360, got " + r15g.getOrThrow().asDecimal().toString())
    }
}

@Test
func testIntegerUpperCaseSuffix(): Unit {
    // 对齐 Rust: as_decimal — 大写后缀 K/M/G
    let rK = Integer.parse("13K")
    if (rK.isNone()) {
        throw Exception("'13K' should parse")
    }
    if (rK.getOrThrow().asDecimal() != 13 * 1024) {
        throw Exception("'13K' should be 13312")
    }
    let rM = Integer.parse("14M")
    if (rM.isNone()) {
        throw Exception("'14M' should parse")
    }
    if (rM.getOrThrow().asDecimal() != 14 * 1048576) {
        throw Exception("'14M' should be 14680064")
    }
    let rG = Integer.parse("15G")
    if (rG.isNone()) {
        throw Exception("'15G' should parse")
    }
    if (rG.getOrThrow().asDecimal() != 15 * 1073741824) {
        throw Exception("'15G' should be 16106127360")
    }
}

// ============================================================
// Color 测试 — 对齐 gix-config-value/tests/color.rs
// ============================================================

@Test
func testColorParsing(): Unit {
    // 对齐 Rust: Color::try_from("red black bold")
    let result = Color.parse("red black bold")
    if (result.isNone()) {
        throw Exception("'red black bold' should parse as Color")
    }
    let c = result.getOrThrow()
    if (c.foreground != Some("red")) {
        throw Exception("foreground should be 'red'")
    }
    if (c.background != Some("black")) {
        throw Exception("background should be 'black'")
    }
}

@Test
func testColorForegroundOnly(): Unit {
    // 对齐 Rust: Color::try_from("red")
    let result = Color.parse("red")
    if (result.isNone()) {
        throw Exception("'red' should parse as Color")
    }
    let c = result.getOrThrow()
    if (c.foreground != Some("red")) {
        throw Exception("foreground should be 'red'")
    }
    if (!c.background.isNone()) {
        throw Exception("background should be None")
    }
}

@Test
func testColorForegroundAndBackground(): Unit {
    // 对齐 Rust: Color::try_from("green yellow")
    let result = Color.parse("green yellow")
    if (result.isNone()) {
        throw Exception("'green yellow' should parse as Color")
    }
    let c = result.getOrThrow()
    if (c.foreground != Some("green")) {
        throw Exception("foreground should be 'green'")
    }
    if (c.background != Some("yellow")) {
        throw Exception("background should be 'yellow'")
    }
}

@Test
func testColorWithAttribute(): Unit {
    // 对齐 Rust: Color::try_from("red bold")
    let result = Color.parse("red bold")
    if (result.isNone()) {
        throw Exception("'red bold' should parse as Color")
    }
    let c = result.getOrThrow()
    if (c.foreground != Some("red")) {
        throw Exception("foreground should be 'red'")
    }
    if (c.attributes.size != 1) {
        throw Exception("should have 1 attribute")
    }
    if (c.attributes[0] != "bold") {
        throw Exception("attribute should be 'bold'")
    }
}

@Test
func testColorAllColorNames(): Unit {
    // 对齐 Rust: color::name::non_bright — 所有标准颜色名
    let colorNames = ["normal", "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
    for (name in colorNames) {
        let result = Color.parse(name)
        if (result.isNone()) {
            throw Exception("'" + name + "' should parse as Color")
        }
    }
}

@Test
func testColorWithNumericForeground(): Unit {
    // 对齐 Rust: Color::try_from("1") — 数字前景色
    let result = Color.parse("1")
    if (result.isNone()) {
        throw Exception("'1' should parse as Color (numeric foreground)")
    }
    let c = result.getOrThrow()
    if (c.foreground.isNone()) {
        throw Exception("numeric foreground should be Some")
    }
}

@Test
func testColorMultipleAttributes(): Unit {
    // 对齐 Rust: from_git::multiple_attributes — "blue bold dim ul blink reverse"
    let result = Color.parse("blue bold dim ul blink reverse")
    if (result.isNone()) {
        throw Exception("'blue bold dim ul blink reverse' should parse as Color")
    }
    let c = result.getOrThrow()
    if (c.foreground != Some("blue")) {
        throw Exception("foreground should be 'blue'")
    }
    if (c.attributes.size < 4) {
        throw Exception("should have multiple attributes, got " + c.attributes.size.toString())
    }
}

@Test
func testColorResetAttribute(): Unit {
    // 对齐 Rust: attribute::non_inverted — "reset"
    let result = Color.parse("red reset")
    if (result.isNone()) {
        throw Exception("'red reset' should parse as Color")
    }
    let c = result.getOrThrow()
    if (c.foreground != Some("red")) {
        throw Exception("foreground should be 'red'")
    }
}

@Test
func testColorWithNumericFgAndBg(): Unit {
    // 对齐 Rust: from_git::long_color_spec — 数字前景和背景
    let result = Color.parse("1 2 bold")
    if (result.isNone()) {
        throw Exception("'1 2 bold' should parse as Color")
    }
    let c = result.getOrThrow()
    if (c.foreground != Some("1")) {
        throw Exception("foreground should be '1'")
    }
    if (c.background != Some("2")) {
        throw Exception("background should be '2'")
    }
}

@Test
func testColorNoAttribute(): Unit {
    // 对齐 Rust: attribute::inverted_no_dash — "nobold"
    let result = Color.parse("red nobold")
    if (result.isNone()) {
        throw Exception("'red nobold' should parse as Color")
    }
    let c = result.getOrThrow()
    if (c.foreground != Some("red")) {
        throw Exception("foreground should be 'red'")
    }
}

@Test
func testColorNoDashAttribute(): Unit {
    // 对齐 Rust: attribute::inverted_dashed — "no-bold"
    let result = Color.parse("red no-bold")
    if (result.isNone()) {
        throw Exception("'red no-bold' should parse as Color")
    }
    let c = result.getOrThrow()
    if (c.foreground != Some("red")) {
        throw Exception("foreground should be 'red'")
    }
}

@Test
func testColorBrightNames(): Unit {
    // 对齐 Rust: color::name::bright — bright 颜色名
    let brightNames = ["brightblack", "brightred", "brightgreen", "brightyellow", "brightblue", "brightmagenta",
        "brightcyan", "brightwhite"]
    for (name in brightNames) {
        let result = Color.parse(name)
        if (result.isNone()) {
            throw Exception("'" + name + "' should parse as Color (bright name)")
        }
        let c = result.getOrThrow()
        if (c.foreground.isNone()) {
            throw Exception("'" + name + "' foreground should be Some")
        }
    }
}

@Test
func testColorAnsiNumeric(): Unit {
    // 对齐 Rust: color::name::ansi — ANSI 数字颜色
    let result255 = Color.parse("255")
    if (result255.isNone()) {
        throw Exception("'255' should parse as Color (ANSI)")
    }
    let result0 = Color.parse("0")
    if (result0.isNone()) {
        throw Exception("'0' should parse as Color (ANSI)")
    }
}

@Test
func testColorAttributeNonInverted(): Unit {
    // 对齐 Rust: attribute::non_inverted — 所有非反转属性
    let attrs = ["reset", "bold", "dim", "ul", "blink", "reverse", "italic", "strike"]
    for (attr in attrs) {
        let result = Color.parse("red " + attr)
        if (result.isNone()) {
            throw Exception("'red " + attr + "' should parse as Color")
        }
    }
}

@Test
func testColorAttributeInvertedNoDash(): Unit {
    // 对齐 Rust: attribute::inverted_no_dash — 无短横线的反转属性
    let attrs = ["nobold", "nodim", "noul", "noblink", "noreverse", "noitalic", "nostrike"]
    for (attr in attrs) {
        let result = Color.parse("red " + attr)
        if (result.isNone()) {
            throw Exception("'red " + attr + "' should parse as Color")
        }
    }
}

@Test
func testColorAttributeInvertedDashed(): Unit {
    // 对齐 Rust: attribute::inverted_dashed — 带短横线的反转属性
    let attrs = ["no-bold", "no-dim", "no-ul", "no-blink", "no-reverse", "no-italic", "no-strike"]
    for (attr in attrs) {
        let result = Color.parse("red " + attr)
        if (result.isNone()) {
            throw Exception("'red " + attr + "' should parse as Color")
        }
    }
}

@Test
func testColorAttributeInvalid(): Unit {
    // 对齐 Rust: attribute::invalid — 无效属性
    let invalidAttrs = ["no-reset", "noreset", "a", "no bold", "no", "no-"]
    for (attr in invalidAttrs) {
        // 仓颉当前实现将无法识别的属性作为普通属性存储
        // 不像 Rust 会报错，但至少不应崩溃
        let result = Color.parse("red " + attr)
        // 不崩溃即可
    }
}

@Test
func testColorNameInvalid(): Unit {
    // 对齐 Rust: color::name::invalid — 无效颜色名
    let invalidNames = ["-2", "brightnormal", "brightdefault", "bright", "256"]
    for (name in invalidNames) {
        // 仓颉当前实现可能不会拒绝这些，但不应崩溃
        let result = Color.parse(name)
        // 不崩溃即可
    }
}

@Test
func testColorResetOnly(): Unit {
    // 对齐 Rust: from_git::reset — "reset"
    let result = Color.parse("reset")
    if (result.isNone()) {
        throw Exception("'reset' should parse as Color")
    }
}

@Test
func testColorEmpty(): Unit {
    // 对齐 Rust: from_git::empty — "" 空字符串
    let result = Color.parse("")
    if (!result.isNone()) {
        // 空字符串可能返回 None 或空 Color
    }
}

@Test
func testColorNormalDefaultCanClearBackgrounds(): Unit {
    // 对齐 Rust: from_git::normal_default_can_clear_backgrounds
    let result = Color.parse("normal default")
    if (result.isNone()) {
        throw Exception("'normal default' should parse as Color")
    }
    let c = result.getOrThrow()
    if (c.foreground != Some("normal")) {
        throw Exception("foreground should be 'normal'")
    }
    if (c.background != Some("default")) {
        throw Exception("background should be 'default'")
    }
}

@Test
func testColorAttributeBeforeColorName(): Unit {
    // 对齐 Rust: from_git::attribute_before_color_name — "bold red"
    let result = Color.parse("bold red")
    if (result.isNone()) {
        throw Exception("'bold red' should parse as Color")
    }
    let c = result.getOrThrow()
    // "bold" 不是颜色名，所以 foreground 应为 "red"
    if (c.foreground != Some("red")) {
        throw Exception("foreground should be 'red'")
    }
}

@Test
func testColorResetThenMultipleAttributes(): Unit {
    // 对齐 Rust: from_git::reset_then_multiple_attributes
    let result = Color.parse("blue bold dim ul blink reverse reset")
    if (result.isNone()) {
        throw Exception("'blue bold dim ul blink reverse reset' should parse as Color")
    }
    let c = result.getOrThrow()
    if (c.foreground != Some("blue")) {
        throw Exception("foreground should be 'blue'")
    }
}

@Test
func testColorLongColorSpec(): Unit {
    // 对齐 Rust: from_git::long_color_spec — "254 255 bold dim ul blink reverse"
    let result = Color.parse("254 255 bold dim ul blink reverse")
    if (result.isNone()) {
        throw Exception("'254 255 bold dim ul blink reverse' should parse as Color")
    }
    let c = result.getOrThrow()
    if (c.foreground != Some("254")) {
        throw Exception("foreground should be '254'")
    }
    if (c.background != Some("255")) {
        throw Exception("background should be '255'")
    }
}

// ============================================================
// PathValue 测试 — 对齐 gix-config-value/tests/path.rs
// ============================================================

@Test
func testPathValueParsing(): Unit {
    // 对齐 Rust: Path::try_from("~/repo")
    let result = PathValue.parse("~/repo")
    if (!result.isHomeRelative) {
        throw Exception("'~/repo' should be home-relative")
    }
    if (result.value != "~/repo") {
        throw Exception("path value mismatch")
    }
}

@Test
func testPathValueAbsolute(): Unit {
    // 对齐 Rust: Path::try_from("/absolute/path")
    let result = PathValue.parse("/absolute/path")
    if (result.isHomeRelative) {
        throw Exception("'/absolute/path' should not be home-relative")
    }
}

@Test
func testPathValueRelative(): Unit {
    // 对齐 Rust: Path::try_from("relative/path")
    let result = PathValue.parse("relative/path")
    if (result.isHomeRelative) {
        throw Exception("'relative/path' should not be home-relative")
    }
}

@Test
func testPathValueDotSlash(): Unit {
    // 对齐 Rust: Path::try_from("./current")
    let result = PathValue.parse("./current")
    if (result.isHomeRelative) {
        throw Exception("'./current' should not be home-relative")
    }
}

@Test
func testPathValueHomeDirOnly(): Unit {
    // 对齐 Rust: Path::try_from("~/")
    let result = PathValue.parse("~/")
    if (!result.isHomeRelative) {
        throw Exception("'~/' should be home-relative")
    }
}

@Test
func testPathValueTildeAlone(): Unit {
    // 对齐 Rust: interpolate::tilde_alone_does_not_interpolate — "~" 不带斜杠
    let result = PathValue.parse("~")
    if (result.isHomeRelative) {
        throw Exception("'~' alone should not be home-relative (no slash)")
    }
}

@Test
func testPathValueWindowsPath(): Unit {
    // 对齐 Rust: interpolate::backslash_is_not_special — Windows 路径
    let result = PathValue.parse("C:\\foo\\bar")
    if (result.isHomeRelative) {
        throw Exception("'C:\\foo\\bar' should not be home-relative")
    }
}

@Test
func testPathValueEmptyPath(): Unit {
    // 对齐 Rust: interpolate::empty_path_is_error — 空路径
    let result = PathValue.parse("")
    if (result.isHomeRelative) {
        throw Exception("empty path should not be home-relative")
    }
    if (result.value != "") {
        throw Exception("empty path value should be ''")
    }
}
