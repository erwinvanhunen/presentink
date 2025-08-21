//
//  PresentationTimerOverlayView.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-08-21.
//


// swift
import Cocoa

final class PresentationTimerOverlayView: NSView {
    private let container = NSView()
    private let label = NSTextField(labelWithString: "00:00")
    private var timer: Timer?
    private var startDate: Date?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        // Background container with rounded corners
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        container.layer?.cornerRadius = 10
        addSubview(container)

        // Time label
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 20, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byClipping
        container.addSubview(label)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),

            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func start() {
        reset()
        startDate = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        startDate = nil
        label.stringValue = "00:00"
    }

    private func tick() {
        guard let start = startDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        label.stringValue = Self.format(elapsed)
    }

    private static func format(_ t: TimeInterval) -> String {
        let seconds = Int(t.rounded(.down))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}