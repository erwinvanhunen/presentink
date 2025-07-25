import Cocoa

class BreakTimerWindowController: NSWindowController {
    private var timerLabel: NSTextField!
    private var breakLabel: NSTextField!
    private var countdown: Int
    private var timer: Timer?

    init(screen: NSScreen) {
        // Get breakMinutes from settings and convert to seconds
        let minutes = Settings.shared.breakMinutes
        self.countdown = minutes * 60
        let window = BreakTimerWindow(
            contentRect: NSRect(origin: .zero, size: screen.frame.size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .mainMenu + 1
        window.backgroundColor = .white
        window.isOpaque = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.makeKeyAndOrderFront(nil)
        window.ignoresMouseEvents = false
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window)

        super.init(window: window)
        setupLabels(frame: window.contentView!.bounds)
        startCountdown()
    }

    override var acceptsFirstResponder: Bool { return true }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLabels(frame: CGRect) {
        guard let contentView = window?.contentView else { return }

        timerLabel = NSTextField(labelWithString: formatTime(countdown))
        timerLabel.font = NSFont.systemFont(ofSize: 120, weight: .bold)
        timerLabel.textColor = .red
        timerLabel.alignment = .center
        timerLabel.backgroundColor = .clear
        timerLabel.isBordered = false
        timerLabel.isEditable = false
        timerLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(timerLabel)

        let breakMessage = Settings.shared.breakMessage
        breakLabel = NSTextField(labelWithString: breakMessage)
        breakLabel.font = NSFont.systemFont(ofSize: 48, weight: .medium)
        breakLabel.textColor = .black
        breakLabel.alignment = .center
        breakLabel.backgroundColor = .clear
        breakLabel.isBordered = false
        breakLabel.isEditable = false
        breakLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(breakLabel)

        NSLayoutConstraint.activate([
            // Center timerLabel horizontally and vertically (with offset)
            timerLabel.centerXAnchor.constraint(
                equalTo: contentView.centerXAnchor
            ),
            timerLabel.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor,
                constant: -60
            ),
            timerLabel.widthAnchor.constraint(
                lessThanOrEqualTo: contentView.widthAnchor,
                multiplier: 0.9
            ),

            // Center breakLabel horizontally, place below timerLabel
            breakLabel.centerXAnchor.constraint(
                equalTo: contentView.centerXAnchor
            ),
            breakLabel.topAnchor.constraint(
                equalTo: timerLabel.bottomAnchor,
                constant: 40
            ),
            breakLabel.widthAnchor.constraint(
                lessThanOrEqualTo: contentView.widthAnchor,
                multiplier: 0.9
            ),
        ])
    }

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            self.countdown -= 1
            self.timerLabel.stringValue = self.formatTime(self.countdown)
            if self.countdown <= 0 {
                self.timer?.invalidate()
                self.close()
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let min = seconds / 60
        let sec = seconds % 60
        return String(format: "%02d:%02d", min, sec)
    }
}
