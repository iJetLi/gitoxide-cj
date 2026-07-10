// 文件：url_test.cj
// 用途：gix_url 包的单元测试，全量对齐 Rust gitoxide gix-url 测试
// 所属包：gix.gix_url
// 对齐来源：gix-url/tests/{parse,serialize}.rs

package gitoxide.gix_url

import std.unittest.*

// ============================================================
// Scheme 测试
// ============================================================

@Test
func testSchemeVariants(): Unit {
    // 对齐 Rust: gix-url/src/lib.rs Scheme 枚举变体
    let schemes: Array<Scheme> = [Scheme.Local, Scheme.File, Scheme.Git, Scheme.Ssh, Scheme.Http, Scheme.Https]
    if (schemes.size != 6) {
        throw Exception("should have 6 scheme variants")
    }
}

// ============================================================
// Url.parse 测试 — 对齐 gix-url/tests/parse.rs
// ============================================================

@Test
func testUrlParseHttps(): Unit {
    // 对齐 Rust: parse https URL
    let url = Url.parse("https://github.com/byron/gitoxide")
    if (url.isNone()) {
        throw Exception("https URL should parse")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Https) {
        throw Exception("scheme should be Https")
    }
    if (u.host != Some("github.com")) {
        throw Exception("host should be github.com")
    }
    if (u.path != "/byron/gitoxide") {
        throw Exception("path should be /byron/gitoxide")
    }
}

@Test
func testUrlParseHttp(): Unit {
    // 对齐 Rust: parse http URL
    let url = Url.parse("http://example.com/repo.git")
    if (url.isNone()) {
        throw Exception("http URL should parse")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Http) {
        throw Exception("scheme should be Http")
    }
    if (u.host != Some("example.com")) {
        throw Exception("host should be example.com")
    }
}

@Test
func testUrlParseGit(): Unit {
    // 对齐 Rust: parse git:// URL
    let url = Url.parse("git://github.com/byron/gitoxide")
    if (url.isNone()) {
        throw Exception("git URL should parse")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Git) {
        throw Exception("scheme should be Git")
    }
}

@Test
func testUrlParseSsh(): Unit {
    // 对齐 Rust: parse ssh:// URL
    let url = Url.parse("ssh://git@github.com/byron/gitoxide")
    if (url.isNone()) {
        throw Exception("ssh URL should parse")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Ssh) {
        throw Exception("scheme should be Ssh")
    }
    if (u.user != Some("git")) {
        throw Exception("user should be git")
    }
    if (u.host != Some("github.com")) {
        throw Exception("host should be github.com")
    }
}

@Test
func testUrlParseFile(): Unit {
    // 对齐 Rust: parse file:// URL
    let url = Url.parse("file:///path/to/repo")
    if (url.isNone()) {
        throw Exception("file URL should parse")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.File) {
        throw Exception("scheme should be File")
    }
    if (u.path != "/path/to/repo") {
        throw Exception("path should be /path/to/repo")
    }
}

@Test
func testUrlParseScpStyle(): Unit {
    // 对齐 Rust: parse SCP-style URL
    let url = Url.parse("git@github.com:byron/gitoxide")
    if (url.isNone()) {
        throw Exception("SCP-style URL should parse")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Ssh) {
        throw Exception("SCP-style scheme should be Ssh")
    }
    if (u.user != Some("git")) {
        throw Exception("SCP-style user should be git")
    }
    if (u.host != Some("github.com")) {
        throw Exception("SCP-style host should be github.com")
    }
}

@Test
func testUrlParseLocalPath(): Unit {
    // 对齐 Rust: parse local path
    let url = Url.parse("/path/to/repo")
    if (url.isNone()) {
        throw Exception("local path should parse")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Local) {
        throw Exception("local path scheme should be Local")
    }
    if (u.path != "/path/to/repo") {
        throw Exception("local path should be /path/to/repo")
    }
}

@Test
func testUrlParseLocalRelativePath(): Unit {
    // 对齐 Rust: parse relative local path
    let url = Url.parse("./repo")
    if (url.isNone()) {
        throw Exception("relative path should parse")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Local) {
        throw Exception("relative path scheme should be Local")
    }
}

@Test
func testUrlParseWithPort(): Unit {
    // 对齐 Rust: parse URL with port
    let url = Url.parse("https://github.com:8443/byron/gitoxide")
    if (url.isNone()) {
        throw Exception("URL with port should parse")
    }
    let u = url.getOrThrow()
    if (u.port != Some(8443)) {
        throw Exception("port should be 8443")
    }
}

// ============================================================
// Url.toString 测试 — 对齐 gix-url/tests/serialize.rs
// ============================================================

@Test
func testUrlToStringHttps(): Unit {
    // 对齐 Rust: serialize https URL
    let url = Url(Scheme.Https, None, Some("github.com"), None, "/byron/gitoxide")
    if (url.toString() != "https://github.com/byron/gitoxide") {
        throw Exception("https toString mismatch: " + url.toString())
    }
}

@Test
func testUrlToStringHttp(): Unit {
    // 对齐 Rust: serialize http URL
    let url = Url(Scheme.Http, None, Some("example.com"), None, "/repo.git")
    if (url.toString() != "http://example.com/repo.git") {
        throw Exception("http toString mismatch: " + url.toString())
    }
}

@Test
func testUrlToStringGit(): Unit {
    // 对齐 Rust: serialize git:// URL
    let url = Url(Scheme.Git, None, Some("github.com"), None, "/byron/gitoxide")
    if (url.toString() != "git://github.com/byron/gitoxide") {
        throw Exception("git toString mismatch: " + url.toString())
    }
}

@Test
func testUrlToStringFile(): Unit {
    // 对齐 Rust: serialize file:// URL
    let url = Url(Scheme.File, None, None, None, "/path/to/repo")
    if (url.toString() != "file:///path/to/repo") {
        throw Exception("file toString mismatch: " + url.toString())
    }
}

@Test
func testUrlToStringLocal(): Unit {
    // 对齐 Rust: serialize local path
    let url = Url(Scheme.Local, None, None, None, "/path/to/repo")
    if (url.toString() != "/path/to/repo") {
        throw Exception("local toString mismatch: " + url.toString())
    }
}

@Test
func testUrlToStringWithPort(): Unit {
    // 对齐 Rust: serialize URL with port
    let url = Url(Scheme.Https, None, Some("github.com"), Some(8443), "/repo")
    let s = url.toString()
    if (!s.contains("8443")) {
        throw Exception("URL with port should contain port number: " + s)
    }
}

// ============================================================
// Url round-trip 测试
// ============================================================

@Test
func testUrlRoundTripHttps(): Unit {
    // 对齐 Rust: parse → toString round-trip
    let original = "https://github.com/byron/gitoxide"
    let url = Url.parse(original)
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let serialized = url.getOrThrow().toString()
    if (serialized != original) {
        throw Exception("round-trip mismatch: " + serialized)
    }
}

@Test
func testUrlRoundTripGit(): Unit {
    // 对齐 Rust: parse → toString round-trip
    let original = "git://github.com/byron/gitoxide"
    let url = Url.parse(original)
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let serialized = url.getOrThrow().toString()
    if (serialized != original) {
        throw Exception("round-trip mismatch: " + serialized)
    }
}

// ============================================================
// HTTP/HTTPS 补充测试 — 对齐 gix-url/tests/parse/http.rs
// ============================================================

@Test
func testHttpWithPort(): Unit {
    // 对齐 Rust: gix-url/tests/parse/http.rs::username_and_password_and_port
    let url = Url.parse("http://example.com:8080/repo")
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Http) {
        throw Exception("scheme should be Http")
    }
    if (u.port != Some(Int64(8080))) {
        throw Exception("port should be 8080")
    }
}

@Test
func testHttpsWithPort(): Unit {
    // 对齐 Rust: gix-url/tests/parse/http.rs::secure + port
    let url = Url.parse("https://example.com:8443/repo")
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Https) {
        throw Exception("scheme should be Https")
    }
    if (u.port != Some(Int64(8443))) {
        throw Exception("port should be 8443")
    }
}

@Test
func testHttpUsernameExpansion(): Unit {
    // 对齐 Rust: gix-url/tests/parse/http.rs::username_expansion_is_unsupported
    let url = Url.parse("http://example.com/~byron/hello")
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let u = url.getOrThrow()
    if (!u.path.contains("~byron")) {
        throw Exception("path should contain ~byron")
    }
}

// ============================================================
// SSH 补充测试 — 对齐 gix-url/tests/parse/ssh.rs
// ============================================================

@Test
func testSshWithoutUserAndPort(): Unit {
    // 对齐 Rust: gix-url/tests/parse/ssh.rs::without_user_and_without_port
    let url = Url.parse("ssh://host.xz/path/to/repo.git/")
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Ssh) {
        throw Exception("scheme should be Ssh")
    }
    if (u.host != Some("host.xz")) {
        throw Exception("host should be host.xz")
    }
}

@Test
func testSshWithUserAndPort(): Unit {
    // 对齐 Rust: gix-url/tests/parse/ssh.rs::with_user_and_port_and_absolute_path
    let url = Url.parse("ssh://user@host.xz:42/.git")
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Ssh) {
        throw Exception("scheme should be Ssh")
    }
    if (u.user != Some("user")) {
        throw Exception("user should be 'user'")
    }
    if (u.port != Some(Int64(42))) {
        throw Exception("port should be 42")
    }
}

@Test
func testScpLikeWithoutUser(): Unit {
    // 对齐 Rust: gix-url/tests/parse/ssh.rs::scp_like_without_user
    let url = Url.parse("host.xz:path/to/git")
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Ssh) {
        throw Exception("SCP-like should be Ssh")
    }
    if (u.host != Some("host.xz")) {
        throw Exception("host should be host.xz")
    }
}

@Test
func testScpLikeWithUserAndRelativePath(): Unit {
    // 对齐 Rust: gix-url/tests/parse/ssh.rs::scp_like_with_user_and_relative_path_keep_relative_path
    let url = Url.parse("user@host.xz:relative")
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let u = url.getOrThrow()
    if (u.user != Some("user")) {
        throw Exception("user should be 'user'")
    }
}

// ============================================================
// File 补充测试 — 对齐 gix-url/tests/parse/file.rs
// ============================================================

@Test
func testFilePathWithProtocol(): Unit {
    // 对齐 Rust: gix-url/tests/parse/file.rs::file_path_with_protocol
    let url = Url.parse("file:///path/to/git")
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.File) {
        throw Exception("scheme should be File")
    }
}

@Test
func testFilePathWithoutProtocol(): Unit {
    // 对齐 Rust: gix-url/tests/parse/file.rs::file_path_without_protocol
    let url = Url.parse("/path/to/git")
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Local) {
        throw Exception("scheme should be Local")
    }
}

// ============================================================
// Git 协议补充测试 — 对齐 gix-url/tests/parse/mod.rs
// ============================================================

@Test
func testGitWithExplicitPort(): Unit {
    // 对齐 Rust: gix-url/tests/parse/git.rs::git_with_explicit_port
    let url = Url.parse("git://example.com:1234/repo")
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Git) {
        throw Exception("scheme should be Git")
    }
    if (u.port != Some(Int64(1234))) {
        throw Exception("port should be 1234")
    }
}

@Test
func testGitUsernameExpansion(): Unit {
    // 对齐 Rust: gix-url/tests/parse/git.rs::username_expansion_with_username
    let url = Url.parse("git://example.com/~byron/hello")
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let u = url.getOrThrow()
    if (!u.path.contains("~byron")) {
        throw Exception("path should contain ~byron")
    }
}

// ============================================================
// 往返测试补充 — 对齐 gix-url/tests/access.rs
// ============================================================

@Test
func testRoundTripSshWithUser(): Unit {
    // 对齐 Rust: gix-url/tests/parse/ssh.rs::with_user_and_without_port (round-trip)
    let original = "ssh://user@host.xz/.git"
    let url = Url.parse(original)
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let serialized = url.getOrThrow().toString()
    if (serialized != original) {
        throw Exception("round-trip mismatch: " + serialized)
    }
}

@Test
func testRoundTripSshWithPort(): Unit {
    // 对齐 Rust: gix-url/tests/parse/ssh.rs::bad_alternative_form_with_port (round-trip)
    let original = "ssh://host.xz:21/"
    let url = Url.parse(original)
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let serialized = url.getOrThrow().toString()
    if (serialized != original) {
        throw Exception("round-trip mismatch: " + serialized)
    }
}

@Test
func testRoundTripFile(): Unit {
    // 对齐 Rust: gix-url/tests/parse/file.rs::file_path_with_protocol (round-trip)
    let original = "file:///path/to/git"
    let url = Url.parse(original)
    if (url.isNone()) {
        throw Exception("parse should succeed")
    }
    let serialized = url.getOrThrow().toString()
    if (serialized != original) {
        throw Exception("round-trip mismatch: " + serialized)
    }
}
