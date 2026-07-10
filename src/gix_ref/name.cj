// 文件：name.cj
// 用途：定义 Git 引用的部分名称类型，用于引用名补全场景
// 所属包：gix.gix_ref
// 关键类型：PartialName

package gitoxide.gix_ref

// 引用的部分名称，表示不完整的引用路径
// 常用于引用名自动补全和模糊匹配场景
public class PartialName {
    // 部分名称字符串
    public var value: String

    // 构造函数
    // 参数 value：部分名称字符串
    public init(value: String) {
        this.value = value
    }
}
