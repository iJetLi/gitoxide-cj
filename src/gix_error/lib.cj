// 文件：lib.cj
// 用途：定义 gix-cj 项目的基础错误类型体系，包括通用错误、消息错误、验证错误及异常链
// 所属包：gix.gix_error
// 关键类型：GixError, Message, ValidationError, Exn
// 关键函数：message()

package gitoxide.gix_error

// gix-cj 所有错误类型的基类，继承自 Exception
// 作为整个项目错误层次结构的根类型
public open class GixError <: Exception {
    // 创建一个默认的 GixError，消息为 "gix error"
    public init() {
        super("gix error")
    }
    // 创建一个带有自定义消息的 GixError
    // 参数 message：错误描述信息
    public init(message: String) {
        super(message)
    }
}

// 携带简单文本消息的错误类型
// 用于需要传递描述性错误信息的场景
public class Message <: GixError {
    // 创建一个带有指定消息的 Message 错误
    // 参数 message：错误描述信息
    public init(message: String) {
        super(message)
    }
}

// 输入验证失败时抛出的错误类型
// 可选地携带导致验证失败的原始输入值
public class ValidationError <: GixError {
    // 导致验证失败的原始输入值，可能为空
    var input: ?String
    // 创建一个仅包含消息的 ValidationError
    // 参数 message：验证失败的原因描述
    public init(message: String) {
        super(message)
        input = None
    }
    // 创建一个包含消息和原始输入值的 ValidationError
    // 参数 message：验证失败的原因描述
    // 参数 inputVal：导致验证失败的原始输入
    public init(message: String, inputVal: String) {
        super(message)
        input = Some(inputVal)
    }
}

// 带有位置信息和异常链的异常包装器
// 用于在错误传播过程中记录发生位置和因果链
public class Exn <: Exception {
    // 被包装的内部 GixError，可能为空
    var inner: ?GixError
    // 错误发生的位置描述
    var location: String
    // 导致此异常的上一个异常，用于构建异常链
    var cause: ?Exn

    // 创建一个包含 GixError 的 Exn
    // 参数 err：被包装的原始错误
    public init(err: GixError) {
        super(err.message)
        inner = Some(err)
        location = ""
        cause = None
    }

    // 创建一个包含 GixError 和位置信息的 Exn
    // 参数 err：被包装的原始错误
    // 参数 loc：错误发生的位置描述
    public init(err: GixError, loc: String) {
        super(err.message + " at " + loc)
        inner = Some(err)
        location = loc
        cause = None
    }

    // 创建一个新的 Exn，将当前异常作为原因链接起来
    // 参数 msg：新异常的错误消息
    // 返回值：新的 Exn 实例，其 cause 指向当前实例
    public func orRaise<E>(msg: String): Exn where E <: GixError {
        let newErr = Message(msg)
        let newExn = Exn(newErr)
        newExn.cause = Some(this)
        newExn
    }
}

// 快捷构造函数：创建一个 Message 类型的错误
// 参数 msg：错误描述信息
// 返回值：Message 错误实例
public func message(msg: String): Message {
    Message(msg)
}
