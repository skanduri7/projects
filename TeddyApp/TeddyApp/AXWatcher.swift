import Cocoa
import ApplicationServices   // Accessibility

final class AXWatcher {

    // MARK: public
    func start() {
        // Ask once; user toggles in Settings
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else {
            print("⚠️  Awaiting Accessibility permission…")
            return
        }
        installSystemObserver()
    }

    // MARK: private
    private var sysObserver:  AXObserver?
    private var elemObserver: AXObserver?     // current focused element

    private let sysWide = AXUIElementCreateSystemWide()

    /// 1️⃣  System-wide observer → tells us when focus changes
    private func installSystemObserver() {
        let pid = pid_t(getpid())
        AXObserverCreate(pid, sysCallback, &sysObserver)
        guard let o = sysObserver else { return }

        AXObserverAddNotification(o, sysWide,
                                  kAXFocusedUIElementChangedNotification as CFString, nil)

        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           AXObserverGetRunLoopSource(o), .defaultMode)
        print("✅ AX system observer started")
    }

    /// 2️⃣  Element-specific observer → emits value / title changes
    private func observe(element: AXUIElement) {
        // Clean up previous
        if let old = elemObserver {
            AXObserverRemoveNotification(old, element,
                                         kAXValueChangedNotification as CFString)
        }
        elemObserver = nil

        var newObs: AXObserver?
        let pid = pid_t(getpid())
        AXObserverCreate(pid, elemCallback, &newObs)
        guard let eo = newObs else { return }

        AXObserverAddNotification(eo, element,
                                  kAXValueChangedNotification as CFString, nil)
        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           AXObserverGetRunLoopSource(eo), .defaultMode)
        elemObserver = eo
    }

    // MARK: callbacks --------------------------------------------------

    /// System-wide: focus moved
    private let sysCallback: AXObserverCallback = { _, element, notif, _ in
        guard notif as String == kAXFocusedUIElementChangedNotification as String else { return }
        let watcher = Unmanaged<AXWatcher>.fromOpaque(&dummy).takeUnretainedValue()
        watcher.observe(element: element)
        watcher.dump(element: element, label: "➡️ focus")
    }

    /// Element-specific: its value changed
    private let elemCallback: AXObserverCallback = { _, element, notif, _ in
        let watcher = Unmanaged<AXWatcher>.fromOpaque(&dummy).takeUnretainedValue()
        watcher.dump(element: element, label: "📝 value")
    }

    /// Utility → print role / value / bounds
    private func dump(element: AXUIElement, label: String) {
        var role : CFTypeRef?
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute  as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)

        var pos : CFTypeRef?
        var size: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &pos)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute     as CFString, &size)

        var pt = CGPoint.zero, sz = CGSize.zero
        if let p = pos, let s = size {
            AXValueGetValue(p as! AXValue, .cgPoint, &pt)
            AXValueGetValue(s as! AXValue, .cgSize,  &sz)
        }
        let rect = CGRect(origin: pt, size: sz)
        FusionEngine.shared.ingestAX(role: role as? String ?? "–",
                                         value: value as? String,
                                         rect:  rect)
//        print(label,
//              role as? String ?? "–",
//              value ?? "–",
//              CGRect(origin: pt, size: sz).integral)
    }
}

// Needed so callbacks can get back to `self`
private var dummy = 0
