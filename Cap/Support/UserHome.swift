import Darwin
import Foundation

/// 真实用户主目录。
///
/// 沙盒（App Store 版）下 `FileManager.homeDirectoryForCurrentUser` 与
/// `NSHomeDirectory()` 都指向 `~/Library/Containers/<bundle-id>/Data`，
/// 保存到 `~/Pictures/Screenshots` 会悄悄落到容器里。这里通过 `getpwuid`
/// 取真实主目录；配合 `com.apple.security.assets.pictures.read-write`
/// 权限即可继续使用原来的默认保存位置。非沙盒环境行为不变。
enum UserHome {
    static var realHomeDirectory: URL {
        if let passwd = getpwuid(getuid()), let home = passwd.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var picturesDirectory: URL {
        realHomeDirectory.appendingPathComponent("Pictures", isDirectory: true)
    }
}
