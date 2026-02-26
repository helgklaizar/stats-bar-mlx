import AppKit
import Foundation

// MARK: - Entry Point
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only, no dock
let delegate = AppDelegate()
app.delegate = delegate
app.run()
