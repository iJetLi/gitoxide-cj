// 文件：lib.cj
// 所属包：gix.gix_trace
// 用途：提供轻量级日志追踪基础设施，支持分级日志输出

package gitoxide.gix_trace

// 日志级别
public enum Level {
    | Error // 错误，表示严重问题
    | Warn // 警告，表示潜在问题
    | Info // 信息，表示一般性提示
    | Debug // 调试，用于开发阶段诊断
    | Trace // 追踪，用于最细粒度的执行流程记录
}

extend Level <: Equatable<Level> {
    public operator func ==(other: Level): Bool {
        match (this) {
            case Level.Error => match (other) {
                case Level.Error => true;
                case _ => false
            }
            case Level.Warn => match (other) {
                case Level.Warn => true;
                case _ => false
            }
            case Level.Info => match (other) {
                case Level.Info => true;
                case _ => false
            }
            case Level.Debug => match (other) {
                case Level.Debug => true;
                case _ => false
            }
            case Level.Trace => match (other) {
                case Level.Trace => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: Level): Bool {
        !(this == other)
    }
}

// 以指定级别输出日志消息
// 默认为空操作，可配置为实际输出
// 参数 level：日志级别
// 参数 message：日志消息
public func log(level: Level, message: String): Unit {
}

// 输出 Error 级别日志
// 参数 message：日志消息
public func error(message: String): Unit {
    log(Level.Error, message)
}

// 输出 Warn 级别日志
// 参数 message：日志消息
public func warn(message: String): Unit {
    log(Level.Warn, message)
}

// 输出 Info 级别日志
// 参数 message：日志消息
public func info(message: String): Unit {
    log(Level.Info, message)
}

// 输出 Debug 级别日志
// 参数 message：日志消息
public func debug(message: String): Unit {
    log(Level.Debug, message)
}

// 输出 Trace 级别日志
// 参数 message：日志消息
public func trace(message: String): Unit {
    log(Level.Trace, message)
}
