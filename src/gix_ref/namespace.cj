// 文件：namespace.cj
// 用途：定义 Git 引用命名空间类型，支持引用的分层隔离
// 所属包：gix.gix_ref
// 关键类型：Namespace

package gitoxide.gix_ref

import gitoxide.gix_utils.*

// 引用命名空间，用于将引用隔离到不同的命名空间中
// 命名空间展开为 refs/namespaces/<part>/ 的前缀路径
public class Namespace {
    // 命名空间的完整路径前缀
    public var value: String

    // 构造函数
    // 参数 value：命名空间路径
    public init(value: String) {
        this.value = value
    }

    // 获取命名空间的字符串表示
    // 返回值：命名空间路径字符串
    public func asBstr(): String {
        value
    }

    // 将简写命名空间展开为完整路径前缀
    // 如 "foo/bar" 展开为 "refs/namespaces/foo/refs/namespaces/bar/"
    // 参数 namespace：简写的命名空间字符串
    // 返回值：展开后的 Namespace 实例
    public static func expand(namespace: String): ?Namespace {
        var result = ""
        let parts = namespace.split("/")
        for (part in parts) {
            result = result + "refs/namespaces/" + part + "/"
        }
        Some(Namespace(result))
    }

    // 将引用名加上命名空间前缀
    // 对齐 Rust: Namespace::into_namespaced_ref
    public func intoNamespacedRef(name: FullName): FullName {
        FullName("refs/namespaces/" + value + "/" + name.value)
    }

    // 从路径中剥离命名空间前缀
    // 对齐 Rust: Namespace::strip_namespace
    public static func stripNamespace(path: String): String {
        let prefix = "refs/namespaces/"
        var remaining = path
        while (remaining.startsWith(prefix)) {
            let afterPrefix = substringFromStr(remaining, prefix.size)
            let slashIdx = afterPrefix.indexOf("/")
            match (slashIdx) {
                case Some(idx) => remaining = substringFromStr(afterPrefix, idx + 1)
                case None => break
            }
        }
        remaining
    }
}
