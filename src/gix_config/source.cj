// 文件：source.cj
// 用途：Git 配置来源的枚举定义
// 所属包：gix.gix_config
// 关键类型：ConfigSource

package gitoxide.gix_config

// Git 配置来源类型，标识配置值是从何处读取的
public enum ConfigSource {
    | Local // 仓库本地配置（.git/config）
    | System // 系统级配置（/etc/gitconfig）
    | Global // 用户全局配置（~/.gitconfig）
    | Env // 环境变量提供的配置
    | Cli // 命令行参数提供的配置
    | Api // 编程接口动态设置的配置
}

extend ConfigSource <: Equatable<ConfigSource> {
    public operator func ==(other: ConfigSource): Bool {
        match (this) {
            case ConfigSource.Local => match (other) {
                case ConfigSource.Local => true;
                case _ => false
            }
            case ConfigSource.System => match (other) {
                case ConfigSource.System => true;
                case _ => false
            }
            case ConfigSource.Global => match (other) {
                case ConfigSource.Global => true;
                case _ => false
            }
            case ConfigSource.Env => match (other) {
                case ConfigSource.Env => true;
                case _ => false
            }
            case ConfigSource.Cli => match (other) {
                case ConfigSource.Cli => true;
                case _ => false
            }
            case ConfigSource.Api => match (other) {
                case ConfigSource.Api => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: ConfigSource): Bool {
        !(this == other)
    }
}
