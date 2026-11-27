// Lists on-screen windows: id, owner, title, bounds in screen points. Usage: windows [owner substring]
import Foundation
import CoreGraphics
let filter = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    if !filter.isEmpty && !owner.localizedCaseInsensitiveContains(filter) { continue }
    let id = w[kCGWindowNumber as String] as? Int ?? 0
    let title = w[kCGWindowName as String] as? String ?? ""
    let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    print(id, owner, "|", title, "|", b["X"] ?? 0, b["Y"] ?? 0, b["Width"] ?? 0, b["Height"] ?? 0)
}
