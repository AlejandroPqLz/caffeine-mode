import SwiftUI
import AppKit
@preconcurrency import UserNotifications
import ServiceManagement

@main
struct CaffeineModeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - Mode

enum CaffeineMode: CaseIterable, Equatable {
    case longRuns
    case mlTraining

    var title: String {
        switch self {
        case .longRuns:   return "Long Runs"
        case .mlTraining: return "ML Training"
        }
    }

    var color: NSColor {
        switch self {
        case .longRuns:   return NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
        case .mlTraining: return NSColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0)
        }
    }

    var args: [String] {
        switch self {
        case .longRuns:   return ["-di"]
        case .mlTraining: return ["-dim"]
        }
    }

    var tooltip: String {
        switch self {
        case .longRuns:
            return "caffeinate -di\nPrevents idle sleep and screen off.\nDisk may sleep.\nBest for long tasks needing screen active."
        case .mlTraining:
            return "caffeinate -dim\nBlocks all sleep: system, screen, and disk.\nBest for model training or intensive workloads"
        }
    }
}

// MARK: - Settings

struct SettingsManager {
    private enum Key {
        static let hideFromDock = "hideFromDock"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.hideFromDock: true,
        ])
    }

    var hideFromDock: Bool {
        get { UserDefaults.standard.bool(forKey: Key.hideFromDock) }
        set { UserDefaults.standard.set(newValue, forKey: Key.hideFromDock) }
    }

    var isLaunchAtLoginEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    mutating func toggleLaunchAtLogin() throws {
        guard #available(macOS 13.0, *) else { return }
        if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        } else {
            try SMAppService.mainApp.register()
        }
    }
}

// MARK: - Tooltip Panel

class TooltipPanel: NSPanel {
    static func show(text: String, leftOfMenu menuMinX: CGFloat, atY y: CGFloat) -> TooltipPanel {
        let panel = TooltipPanel(text: text)
        panel.positionLeft(of: menuMinX, atY: y)
        panel.orderFront(nil)
        return panel
    }

    init(text: String) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]

        let effect = NSVisualEffectView()
        effect.material = .toolTip
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = 4

        let attributed = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            let isBold = line.hasPrefix("caffeinate") || line.hasPrefix("pmset")
            var attrs: [NSAttributedString.Key: Any] = [
                .font: isBold ? NSFont.boldSystemFont(ofSize: 12) : NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor,
            ]
            if i > 0 { attrs[.paragraphStyle] = paragraphStyle }
            if !attributed.string.isEmpty { attributed.append(NSAttributedString(string: "\n")) }
            attributed.append(NSAttributedString(string: line, attributes: attrs))
        }

        let label = NSTextField(wrappingLabelWithString: "")
        label.attributedStringValue = attributed
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: effect.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -12),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
        ])

        contentView = effect
        let fitting = effect.fittingSize
        setContentSize(NSSize(width: max(fitting.width, 180), height: fitting.height))
    }

    func positionLeft(of menuMinX: CGFloat, atY y: CGFloat) {
        var origin = NSPoint(x: menuMinX - frame.width - 6, y: y - frame.height / 2)
        let ref = NSPoint(x: origin.x, y: y)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(ref) }) ?? NSScreen.main {
            origin.x = max(origin.x, screen.visibleFrame.minX + 4)
            origin.y = max(origin.y, screen.visibleFrame.minY + 4)
            origin.y = min(origin.y, screen.visibleFrame.maxY - frame.height - 4)
        }
        setFrameOrigin(origin)
    }
}

// MARK: - Toggle Menu Item View

class ToggleMenuItemView: NSView {
    static let itemWidth: CGFloat  = 230
    static let itemHeight: CGFloat = 28

    private let titleLabel = NSTextField(labelWithString: "")
    private var toggleSwitch: NSSwitch?
    private var activeBackground: NSColor?
    private var modeColor: NSColor?
    private var isHovered = false

    var onToggle: (() -> Void)?
    var onHover: ((Bool) -> Void)?

    func setActive(_ active: Bool) {
        activeBackground = active ? modeColor : nil
        needsDisplay = true
    }

    init(title: String, isOn: Bool, dotColor: NSColor? = nil,
         activeBackground: NSColor? = nil, showSwitch: Bool = true) {
        self.modeColor = activeBackground
        self.activeBackground = isOn ? activeBackground : nil
        super.init(frame: NSRect(x: 0, y: 0, width: Self.itemWidth, height: Self.itemHeight))

        var rightEdge = Self.itemWidth - 12

        if showSwitch {
            let sw = NSSwitch()
            sw.controlSize = .small
            sw.sizeToFit()
            sw.state = isOn ? .on : .off
            sw.target = self
            sw.action = #selector(switchChanged)
            // Force active-window appearance so the accent color renders in the menu panel
            sw.appearance = NSApp.effectiveAppearance
            sw.frame = NSRect(
                x: Self.itemWidth - sw.frame.width - 12,
                y: (Self.itemHeight - sw.frame.height) / 2,
                width: sw.frame.width,
                height: sw.frame.height
            )
            addSubview(sw)
            toggleSwitch = sw
            rightEdge = sw.frame.minX - 8
        }

        var x: CGFloat = 14
        if let color = dotColor {
            let d: CGFloat = 10
            let dot = NSView(frame: NSRect(x: x, y: (Self.itemHeight - d) / 2, width: d, height: d))
            dot.wantsLayer = true
            dot.layer?.backgroundColor = color.cgColor
            dot.layer?.cornerRadius = d / 2
            addSubview(dot)
            x += d + 8
        }

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        titleLabel.isEditable = false
        titleLabel.isBezeled = false
        titleLabel.backgroundColor = .clear
        titleLabel.frame = NSRect(x: x, y: (Self.itemHeight - 17) / 2,
                                   width: rightEdge - x, height: 17)
        addSubview(titleLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Re-apply appearance once the view is in the menu window
        toggleSwitch?.appearance = NSApp.effectiveAppearance
        toggleSwitch?.needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true;  needsDisplay = true; onHover?(true) }
    override func mouseExited(with event: NSEvent)  { isHovered = false; needsDisplay = true; onHover?(false) }

    @objc private func switchChanged() { onToggle?() }

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if let sw = toggleSwitch {
            if !sw.frame.contains(loc) { sw.performClick(self) }
        } else {
            onToggle?()
        }
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 4, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        if let bg = activeBackground {
            bg.withAlphaComponent(0.30).setFill()
            path.fill()
        }
        if isHovered {
            NSColor.labelColor.withAlphaComponent(0.09).setFill()
            path.fill()
        }
        super.draw(dirtyRect)
    }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var caffeineProcess: Process?
    var activeMode: CaffeineMode?
    var tooltipPanel: TooltipPanel?
    var settings = SettingsManager()
    var modeViews: [CaffeineMode: ToggleMenuItemView] = [:]

    func updateModeViews() {
        for (mode, view) in modeViews {
            view.setActive(activeMode == mode)
        }
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsManager.registerDefaults()
        applyDockPolicy()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = createCoffeeIcon(activeColor: nil)

        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }

    func applicationWillTerminate(_ notification: Notification) {
        if activeMode != nil {
            stopMode(silent: true)
        }
    }

    func applyDockPolicy() {
        NSApp.setActivationPolicy(settings.hideFromDock ? .accessory : .regular)
    }

    // MARK: Menu

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        header.isEnabled = false
        header.attributedTitle = NSAttributedString(
            string: "Modes",
            attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
        )
        menu.addItem(header)

        modeViews.removeAll()
        for mode in CaffeineMode.allCases {
            let item = NSMenuItem(title: mode.title, action: nil, keyEquivalent: "")
            item.representedObject = mode
            let view = ToggleMenuItemView(
                title: mode.title, isOn: activeMode == mode,
                dotColor: mode.color, activeBackground: mode.color, showSwitch: false
            )
            modeViews[mode] = view
            view.onToggle = { [weak self] in
                self?.activate(mode: mode)
            }
            view.onHover = { [weak self] entered in
                self?.tooltipPanel?.close()
                self?.tooltipPanel = nil
                guard entered else { return }
                let menuMinX = NSApp.windows
                    .first { $0.isVisible && $0.className.lowercased().contains("menu") }
                    .map { $0.frame.minX } ?? (NSEvent.mouseLocation.x - 160)
                self?.tooltipPanel = TooltipPanel.show(
                    text: mode.tooltip, leftOfMenu: menuMinX, atY: NSEvent.mouseLocation.y)
            }
            item.view = view
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsItem.submenu = buildSettingsSubmenu()
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    func buildSettingsSubmenu() -> NSMenu {
        let sub = NSMenu()

        func toggleItem(title: String, isOn: Bool, action: @escaping () -> Void) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let view = ToggleMenuItemView(title: title, isOn: isOn)
            view.onToggle = action
            item.view = view
            return item
        }

        sub.addItem(toggleItem(title: "Launch at Login", isOn: settings.isLaunchAtLoginEnabled) { [weak self] in self?.toggleLaunchAtLogin() })
        sub.addItem(toggleItem(title: "Hide from Dock",  isOn: settings.hideFromDock)            { [weak self] in self?.toggleHideFromDock() })

        return sub
    }

    func menuDidClose(_ menu: NSMenu) {
        tooltipPanel?.close()
        tooltipPanel = nil
    }

    // MARK: Mode Actions

    func activate(mode: CaffeineMode) {
        statusItem?.menu?.cancelTracking()

        if activeMode == mode {
            stopMode(silent: false)
            return
        }

        if activeMode != nil {
            stopMode(silent: true)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = mode.args
        do {
            try process.run()
            caffeineProcess = process
            activeMode = mode
            updateIcon(for: mode)
            updateModeViews()
            showNotification(title: mode.title, subtitle: "caffeinate \(mode.args.joined(separator: " "))")
        } catch {
            showNotification(title: "Error", subtitle: "Could not start caffeinate")
        }
    }

    func stopMode(silent: Bool) {
        guard let mode = activeMode else { return }
        caffeineProcess?.terminate()
        caffeineProcess = nil
        activeMode = nil
        updateIcon(for: nil)
        updateModeViews()
        if !silent {
            showNotification(title: "\(mode.title) stopped", subtitle: "")
        }
    }

    // MARK: Settings Actions

    @objc func toggleLaunchAtLogin() {
        do {
            try settings.toggleLaunchAtLogin()
        } catch {
            showNotification(title: "Error", subtitle: "Could not change Launch at Login")
        }
    }

    @objc func toggleHideFromDock() {
        settings.hideFromDock.toggle()
        applyDockPolicy()
    }

    // MARK: Icon

    func updateIcon(for mode: CaffeineMode?) {
        statusItem?.button?.image = createCoffeeIcon(activeColor: mode?.color)
    }

    func createCoffeeIcon(activeColor: NSColor?) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard let base = NSImage(systemSymbolName: "cup.and.saucer.fill",
                                 accessibilityDescription: nil)?
                .withSymbolConfiguration(config) else {
            return NSImage()
        }

        guard let color = activeColor else {
            base.isTemplate = true
            return base
        }

        let result = NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)
            color.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
        result.isTemplate = false
        return result
    }

    // MARK: Notifications

    func showNotification(title: String, subtitle: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            if !subtitle.isEmpty { content.subtitle = subtitle }
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }
}
