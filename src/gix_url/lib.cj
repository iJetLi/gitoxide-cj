package gitoxide.gix_url

import gitoxide.gix_utils.*

public enum Scheme {
    | Local
    | File
    | Git
    | Ssh
    | Http
    | Https
}

extend Scheme <: Equatable<Scheme> {
    public operator func ==(other: Scheme): Bool {
        match (this) {
            case Scheme.Local => match (other) {
                case Scheme.Local => true;
                case _ => false
            }
            case Scheme.File => match (other) {
                case Scheme.File => true;
                case _ => false
            }
            case Scheme.Git => match (other) {
                case Scheme.Git => true;
                case _ => false
            }
            case Scheme.Ssh => match (other) {
                case Scheme.Ssh => true;
                case _ => false
            }
            case Scheme.Http => match (other) {
                case Scheme.Http => true;
                case _ => false
            }
            case Scheme.Https => match (other) {
                case Scheme.Https => true;
                case _ => false
            }
        }
    }
}

public class Url {
    public var scheme: Scheme
    public var user: ?String
    public var host: ?String
    public var port: ?Int64
    public var path: String

    public init(scheme: Scheme, user: ?String, host: ?String, port: ?Int64, path: String) {
        this.scheme = scheme
        this.user = user
        this.host = host
        this.port = port
        this.path = path
    }

    public static func parse(input: String): ?Url {
        if (input.startsWith("https://")) {
            return parseRemote(substringFromStr(input, 8), Scheme.Https)
        }
        if (input.startsWith("http://")) {
            return parseRemote(substringFromStr(input, 7), Scheme.Http)
        }
        if (input.startsWith("git://")) {
            return parseRemote(substringFromStr(input, 6), Scheme.Git)
        }
        if (input.startsWith("ssh://")) {
            return parseSshRemote(substringFromStr(input, 6))
        }
        if (input.startsWith("file://")) {
            return Some(Url(Scheme.File, None, None, None, substringFromStr(input, 7)))
        }
        if (input.contains(":")) {
            let colonIdx = input.indexOf(":")
            if (let Some(ci) <- colonIdx) {
                let beforeColon = substringStr(input, 0, ci)
                let afterColon = substringFromStr(input, ci + 1)
                if (beforeColon.contains("/")) {
                    return Some(Url(Scheme.Local, None, None, None, input))
                }
                if (afterColon.size > 0 && !afterColon.startsWith("/")) {
                    return parseScp(input)
                }
                if (afterColon.startsWith("/")) {
                    return Some(Url(Scheme.Ssh, None, Some(beforeColon), None, afterColon))
                }
            }
        }
        Some(Url(Scheme.Local, None, None, None, input))
    }

    public func toString(): String {
        match (scheme) {
            case Scheme.Local => path
            case Scheme.File => "file://" + path
            case Scheme.Http => "http://" + formatHostUser() + path
            case Scheme.Https => "https://" + formatHostUser() + path
            case Scheme.Git => "git://" + formatHostUser() + path
            case Scheme.Ssh => "ssh://" + formatSshUrl()
        }
    }

    func formatHostUser(): String {
        let userPart = if (let Some(u) <- user) {
            u + "@"
        } else {
            ""
        }
        let portPart = if (let Some(p) <- port) {
            ":" + p.toString()
        } else {
            ""
        }
        let h = if (let Some(hv) <- host) {
            hv
        } else {
            ""
        }
        userPart + h + portPart
    }

    func formatSshUrl(): String {
        let userPart = if (let Some(u) <- user) {
            u + "@"
        } else {
            ""
        }
        let portPart = if (let Some(p) <- port) {
            ":" + p.toString()
        } else {
            ""
        }
        let h = if (let Some(hv) <- host) {
            hv
        } else {
            ""
        }
        userPart + h + portPart + path
    }
}

func parseRemote(input: String, scheme: Scheme): ?Url {
    let atIdx = input.indexOf("@")
    var userPart: ?String = None
    var rest = input
    if (let Some(ai) <- atIdx) {
        let slashAfterAt = substringFromStr(input, ai + 1).indexOf("/")
        if (let Some(sa) <- slashAfterAt) {
            let possibleHost = substringStr(input, ai + 1, ai + 1 + sa)
            if (!possibleHost.contains(":") || possibleHost.indexOf(":") != None) {
                userPart = Some(substringStr(input, 0, ai))
                rest = substringFromStr(input, ai + 1)
            }
        } else {
            userPart = Some(substringStr(input, 0, ai))
            rest = substringFromStr(input, ai + 1)
        }
    }
    let slashIdx = rest.indexOf("/")
    if (let Some(si) <- slashIdx) {
        let hostPort = substringStr(rest, 0, si)
        let p = substringFromStr(rest, si)
        let colonIdx = hostPort.indexOf(":")
        if (let Some(ci) <- colonIdx) {
            let h = substringStr(hostPort, 0, ci)
            let portStr = substringFromStr(hostPort, ci + 1)
            let portOpt = parseInt(portStr)
            if (let Some(port) <- portOpt) {
                Some(Url(scheme, userPart, Some(h), Some(port), p))
            } else {
                Some(Url(scheme, userPart, Some(hostPort), None, p))
            }
        } else {
            Some(Url(scheme, userPart, Some(hostPort), None, p))
        }
    } else {
        Some(Url(scheme, userPart, Some(rest), None, "/"))
    }
}

func parseSshRemote(input: String): ?Url {
    let atIdx = input.indexOf("@")
    if (let Some(ai) <- atIdx) {
        let u = substringStr(input, 0, ai)
        let rest = substringFromStr(input, ai + 1)
        parseRemoteWithUser(rest, u)
    } else {
        parseRemote(input, Scheme.Ssh)
    }
}

func parseRemoteWithUser(input: String, user: String): ?Url {
    let slashIdx = input.indexOf("/")
    if (let Some(si) <- slashIdx) {
        let hostPort = substringStr(input, 0, si)
        let p = substringFromStr(input, si)
        let colonIdx = hostPort.indexOf(":")
        if (let Some(ci) <- colonIdx) {
            let h = substringStr(hostPort, 0, ci)
            let portStr = substringFromStr(hostPort, ci + 1)
            let portOpt = parseInt(portStr)
            if (let Some(port) <- portOpt) {
                Some(Url(Scheme.Ssh, Some(user), Some(h), Some(port), p))
            } else {
                Some(Url(Scheme.Ssh, Some(user), Some(hostPort), None, p))
            }
        } else {
            Some(Url(Scheme.Ssh, Some(user), Some(hostPort), None, p))
        }
    } else {
        Some(Url(Scheme.Ssh, Some(user), Some(input), None, "/"))
    }
}

func parseScp(input: String): ?Url {
    let atIdx = input.indexOf("@")
    if (let Some(ai) <- atIdx) {
        let u = substringStr(input, 0, ai)
        let rest = substringFromStr(input, ai + 1)
        let colonIdx = rest.indexOf(":")
        if (let Some(ci) <- colonIdx) {
            let h = substringStr(rest, 0, ci)
            let p = substringFromStr(rest, ci + 1)
            Some(Url(Scheme.Ssh, Some(u), Some(h), None, p))
        } else {
            None
        }
    } else {
        let colonIdx = input.indexOf(":")
        if (let Some(ci) <- colonIdx) {
            let h = substringStr(input, 0, ci)
            let p = substringFromStr(input, ci + 1)
            Some(Url(Scheme.Ssh, None, Some(h), None, p))
        } else {
            None
        }
    }
}
