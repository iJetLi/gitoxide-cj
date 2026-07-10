// 文件：io.cj
// 用途：提供基于字节和流的哈希计算便捷函数
// 所属包：gix.gix_hash
// 关键函数：hashOfBytes

package gitoxide.gix_hash

public func hashOfBytes(kind: HashKind, data: Array<Byte>): ObjectId {
    let hasher = GixHasher(kind)
    hasher.update(data)
    hasher.tryFinalize()
}
