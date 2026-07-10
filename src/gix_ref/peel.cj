// 文件：peel.cj
// 所属包：gix.gix_ref
// 用途：实现引用的 peel 操作，将符号引用逐层解析直到指向最终的对象 ID
// 关键类型：FindObject, 关键函数：peelRef

package gitoxide.gix_ref

import gitoxide.gix_hash.*

// 对引用执行 peel 操作，沿符号引用链解析直到获得最终的对象 ID
// 若引用已有 peeled 值（标签已解引用），则直接返回 peeled 值
// 最大解析深度为 10 层，防止无限循环
// 参数 ref - 待 peel 的引用
// 参数 finder - 引用查找器，用于解析符号引用
// 返回值 - 解析成功返回 Some(ObjectId)，超过深度或解析失败返回 None
public func peelRef(ref: Reference, finder: FindObject): ?ObjectId {
    var current = ref
    var depth: Int64 = 0
    while (depth < 10) {
        if (let Target.Object(id) <- current.target) {
            if (let Some(p) <- current.peeled) {
                return Some(p)
            }
            return Some(id)
        }
        if (let Target.Symbolic(name) <- current.target) {
            let resolved = finder.findRef(name)
            if (let Some(r) <- resolved) {
                current = r
                depth += 1
            } else {
                return None
            }
        }
    }
    None
}

// 引用查找接口，用于在 peel 操作中解析符号引用
// 实现此接口以提供引用查找能力
public interface FindObject {
    // 根据引用全名查找引用
    // 参数 name - 引用全名
    // 返回值 - 找到返回 Some(Reference)，未找到返回 None
    func findRef(name: FullName): ?Reference
}
