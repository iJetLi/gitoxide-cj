// 文件：store/loose.cj
// 用途：松散对象存储，负责 Git 松散对象（.git/objects/xx/xxx...）的读写、存在性检查、哈希校验和原子写入
// 所属包：gix.gix_odb
// 对齐来源：gix-odb/src/store_impls/loose/{mod,find,write,verify,iter}.rs
// 关键类型：LooseStore、LooseVerifyStatistics、LooseVerifyError

package gitoxide.gix_odb.store

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_zlib.*
import gitoxide.gix_utils.*
import std.fs.*
import std.collection.*

// 对齐 Rust: gix-odb/src/store_impls/loose/verify.rs integrity::Statistics
// 松散对象校验统计
public class LooseVerifyStatistics {
    // 校验的松散对象数量
    public var numObjects: Int64

    public init() {
        this.numObjects = 0
    }
}

// 对齐 Rust: gix-odb/src/store_impls/loose/verify.rs integrity::Error
// 松散对象校验错误
public class LooseVerifyError {
    public var kind: ObjectKind
    public var id: ObjectId
    public var message: String

    public init(kind: ObjectKind, id: ObjectId, message: String) {
        this.kind = kind
        this.id = id
        this.message = message
    }
}

// 松散对象校验结果
public class VerifyIntegrityResult {
    public var stats: LooseVerifyStatistics
    public var errors: ArrayList<LooseVerifyError>

    public init(stats: LooseVerifyStatistics, errors: ArrayList<LooseVerifyError>) {
        this.stats = stats
        this.errors = errors
    }
}

// 松散对象存储，管理 .git/objects/ 目录下按哈希前两位分组的松散对象文件
// 每个对象以 zlib 压缩格式存储，文件路径为 objects/<前2位>/<剩余38位>
// 对齐 Rust: gix-odb/src/store_impls/loose/mod.rs Store
public class LooseStore {
    // Git 对象目录路径（如 .git/objects）
    public var objectsDir: String
    // 哈希算法类型（SHA-1 或 SHA-256）
    public var hashKind: HashKind
    // 内存分配上限（字节），None 表示不限制
    // 对齐 Rust: Store.alloc_limit_bytes
    public var allocLimitBytes: ?Int64

    // 构造函数
    // 参数 objectsDir：Git 对象目录路径
    // 参数 hashKind：哈希算法类型
    public init(objectsDir: String, hashKind: HashKind) {
        this.objectsDir = objectsDir
        this.hashKind = hashKind
        this.allocLimitBytes = None
    }

    // 带分配限制的构造函数
    // 对齐 Rust: Store::at(objects_directory, object_hash, alloc_limit_bytes)
    public init(objectsDir: String, hashKind: HashKind, allocLimitBytes: ?Int64) {
        this.objectsDir = objectsDir
        this.hashKind = hashKind
        this.allocLimitBytes = allocLimitBytes
    }

    // 对齐 Rust: gix-odb/src/store_impls/loose/mod.rs hash_path
    // 根据对象 ID 计算文件路径
    public func objectPath(id: ObjectId): String {
        let hex = id.toHexString()
        objectsDir + "/" + substringStr(hex, 0, 2) + "/" + substringFromStr(hex, 2)
    }

    // 根据对象 ID 读取松散对象数据，解压并解析对象头部和内容
    // 对齐 Rust: gix-odb/src/store_impls/loose/find.rs Store::try_find()
    // 参数 id：要读取的对象 ID
    // 返回值：成功则返回包含对象类型和内容的 Data，失败或不存在返回 None
    public func read(id: ObjectId): ?Data {
        let path = objectPath(id)
        if (!exists(path)) {
            return None
        }
        try {
            let compressed = readFileBytes(path)
            // 对齐 Rust: alloc_limit_bytes 检查
            if (let Some(limit) <- allocLimitBytes) {
                if (compressed.size > limit) {
                    return None
                }
            }
            let inflated = inflate(compressed)
            let header = decodeLooseHeader(inflated.data)
            if (header.isSome()) {
                let h = header.getOrThrow()
                let (kind, size, offset) = h
                // 对齐 Rust: find.rs SizeMismatch 检查
                let bodySize = inflated.data.size - offset
                if (bodySize != size) {
                    return None
                }
                let body = sliceBytesOdb(inflated.data, offset, inflated.data.size)
                Some(Data(kind, hashKind, body))
            } else {
                None
            }
        } catch (_: Exception) {
            None
        }
    }

    // 读取松散对象并验证哈希是否匹配
    // 对齐 Rust: gix-odb/src/store_impls/loose/verify.rs — 读取后验证 SHA-1/SHA-256
    // 参数 id：要读取的对象 ID
    // 返回值：数据存在且哈希匹配返回 Data，否则返回 None
    public func readWithVerify(id: ObjectId): ?Data {
        let data = read(id)
        if (data.isNone()) {
            return None
        }
        let d = data.getOrThrow()
        // 重新计算哈希并验证
        let computedId = computeHash(hashKind, d.kind, d.data)
        if (computedId != id) {
            return None
        }
        data
    }

    // 将对象写入松散存储（原子写入）
    // 对齐 Rust: gix-odb/src/store_impls/loose/write.rs Store::write_buf()
    // 写入临时文件 → 重命名到最终路径，保证原子性
    // 参数 kind：对象类型
    // 参数 data：对象的原始字节数据
    // 返回值：写入后生成的对象 ID
    public func write(kind: ObjectKind, data: Array<Byte>): ObjectId {
        let header = looseHeader(kind, data.size)
        let fullData = concatArraysOdb(header, data)
        let id = computeHash(hashKind, kind, data)
        let hex = id.toHexString()
        let dir = objectsDir + "/" + substringStr(hex, 0, 2)
        let finalPath = dir + "/" + substringFromStr(hex, 2)

        // 对齐 Rust: write.rs — 如果文件已存在则跳过
        if (exists(finalPath)) {
            return id
        }

        try {
            if (!exists(dir)) {
                Directory.create(dir)
            }

            // 对齐 Rust: write.rs — 原子写入：先写临时文件，再重命名
            // 1. 写入临时文件
            let tempPath = dir + "/tmp_obj_" + hex + ".tmp"
            let compressed = deflate(fullData)
            writeFileBytes(tempPath, compressed.data)

            // 2. 重命名到最终路径（原子操作）
            // 对齐 Rust: write.rs finalize_object_at — rename temp to final
            try {
                rename(tempPath, to: finalPath, overwrite: false)
            } catch (_: Exception) {
                // rename 失败（可能另一个进程已创建），尝试删除临时文件
                try {
                    remove(tempPath)
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}

        id
    }

    // 检查指定 ID 的松散对象文件是否存在于磁盘上
    // 对齐 Rust: gix-odb/src/store_impls/loose/find.rs Store::contains()
    public func exists(id: ObjectId): Bool {
        let path = objectPath(id)
        exists(path)
    }

    // 遍历所有松散对象 ID
    // 对齐 Rust: gix-odb/src/store_impls/loose/iter.rs Store::iter()
    // 扫描 objectsDir 下的 xx/xxx... 文件，从路径解析出 ObjectId
    public func iter(): ArrayList<ObjectId> {
        let result = ArrayList<ObjectId>()
        if (!exists(objectsDir)) {
            return result
        }
        try {
            let topEntries = Directory.readFrom(objectsDir)
            for (topEntry in topEntries) {
                if (!topEntry.isDirectory()) {
                    continue
                }
                let prefix = topEntry.path.toString()
                // 提取目录名（最后 2 个字符，即十六进制前缀）
                let dirName = substringFromStr(prefix, prefix.size - 2)
                if (dirName.size != 2) {
                    continue
                }
                // 验证是否为合法十六进制
                let prefixHex = parseHexInt64(dirName)
                if (prefixHex.isNone()) {
                    continue
                }
                try {
                    let subEntries = Directory.readFrom(topEntry.path)
                    for (subEntry in subEntries) {
                        if (subEntry.isDirectory()) {
                            continue
                        }
                        let subPath = subEntry.path.toString()
                        // 提取文件名：找最后一个 / 或 \
                        var sepPos: Int64 = -1
                        let fwdIdx = subPath.lastIndexOf("/")
                        if (fwdIdx.isSome()) {
                            sepPos = fwdIdx.getOrThrow()
                        }
                        let backIdx = subPath.lastIndexOf("\\")
                        if (backIdx.isSome()) {
                            let bv = backIdx.getOrThrow()
                            if (bv > sepPos) {
                                sepPos = bv
                            }
                        }
                        let fileName = substringFromStr(subPath, sepPos + 1)
                        let hexStr = dirName + fileName
                        try {
                            let oid = ObjectId.fromHexOrThrow(hexStr)
                            result.add(oid)
                        } catch (_: Exception) {}
                    }
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
        result
    }

    // 校验所有松散对象的完整性
    // 对齐 Rust: gix-odb/src/store_impls/loose/verify.rs Store::verify_integrity()
    // 读取每个对象，重新计算哈希，验证与文件名（ObjectId）是否一致
    // 返回值：校验统计和错误列表
    public func verifyIntegrity(): VerifyIntegrityResult {
        let stats = LooseVerifyStatistics()
        let errors = ArrayList<LooseVerifyError>()

        let ids = iter()
        for (id in ids) {
            stats.numObjects += 1
            let data = read(id)
            if (data.isNone()) {
                // 对齐 Rust: verify.rs Retry — 对象在遍历期间被删除
                errors.add(LooseVerifyError(ObjectKind.Blob, id, "object could not be read"))
                continue
            }
            let d = data.getOrThrow()
            // 对齐 Rust: verify.rs — 重新计算哈希并验证
            let computedId = computeHash(hashKind, d.kind, d.data)
            if (computedId != id) {
                errors.add(
                    LooseVerifyError(d.kind, id,
                        "hash mismatch: expected ${id.toHexString()}, got ${computedId.toHexString()}"))
            }
        }

        VerifyIntegrityResult(stats, errors)
    }
}

// 字节数组切片辅助函数，截取指定范围的字节
func sliceBytesOdb(data: Array<Byte>, start: Int64, end: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    var i = start
    while (i < end) {
        result.add(data[i])
        i += 1
    }
    result.toArray()
}

// 字节数组拼接辅助函数，将两个数组合并为一个
func concatArraysOdb(a: Array<Byte>, b: Array<Byte>): Array<Byte> {
    var result = ArrayList<Byte>()
    for (x in a) {
        result.add(x)
    }
    for (x in b) {
        result.add(x)
    }
    result.toArray()
}
