// 文件：verify.cj
// 用途：提供哈希值验证功能，比较期望哈希与实际哈希是否一致
// 所属包：gix.gix_hash
// 关键函数：verify

package gitoxide.gix_hash

// 验证两个 ObjectId 是否一致
// 逐字节比较期望值与实际值，用于校验数据完整性
// 参数 expected：期望的 ObjectId
// 参数 actual：实际的 ObjectId
// 返回值：匹配时返回 None，不匹配时返回 Some(错误描述)
public func verify(expected: ObjectId, actual: ObjectId): ?String {
    if (expected.bytes.size != actual.bytes.size) {
        return Some("hash length mismatch")
    }
    for (i in 0..expected.bytes.size) {
        if (expected.bytes[i] != actual.bytes[i]) {
            return Some("hash mismatch")
        }
    }
    None
}
