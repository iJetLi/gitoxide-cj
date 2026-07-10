// 文件：lib.cj
// 用途：提供 Git LFS 指针文件解析与序列化功能
// 所属包：gix.gix_lfs
// 关键类型：LfsPointer

package gitoxide.gix_lfs

import gitoxide.gix_utils.*
import std.convert.*

// LFS 指针文件，表示大文件的元数据引用
public class LfsPointer {
    // LFS 对象的 SHA-256 哈希值
    public var oid: String
    // 原始文件的大小（字节）
    public var size: Int64

    // 构造函数
    // 参数 oid：SHA-256 哈希值
    // 参数 size：文件大小
    public init(oid: String, size: Int64) {
        this.oid = oid
        this.size = size
    }

    // 从 LFS 指针文件内容解析
    // 查找 "oid sha256:" 和 "size " 行提取元数据
    // 参数 content：指针文件的文本内容
    // 返回值：解析成功返回 LfsPointer，缺少 oid 返回 None
    public static func parse(content: String): ?LfsPointer {
        let lines = content.split("\n")
        var oid: ?String = None
        var size: Int64 = 0
        for (line in lines) {
            let trimmed = trimStr(line)
            if (trimmed.startsWith("oid sha256:")) {
                oid = Some(substringFromStr(trimmed, 11))
            } else if (trimmed.startsWith("size ")) {
                let sizeStr = substringFromStr(trimmed, 5)
                let sizeOpt = parseInt(sizeStr)
                if (let Some(v) <- sizeOpt) {
                    size = v
                }
            }
        }
        if (let Some(o) <- oid) {
            Some(LfsPointer(o, size))
        } else {
            None
        }
    }

    // 将 LFS 指针序列化为标准格式字符串
    // 返回值：符合 LFS 规范的指针文件内容
    public func toString(): String {
        "version https://git-lfs.github.com/spec/v1\noid sha256:" + oid + "\nsize " + size.toString() + "\n"
    }
}
