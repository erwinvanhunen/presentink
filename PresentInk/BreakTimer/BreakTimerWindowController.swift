import Cocoa

class BreakTimerWindowController: NSWindowController {
    private var timerLabel: NSTextField!
    private var breakLabel: NSTextField!
    private var countdown: Int
    private var timer: Timer?

    init(screen: NSScreen) {
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
        window.backgroundColor = Settings.shared.breakBackgroundColor
        window.isOpaque = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false

        super.init(window: window)
        setupLabels(frame: window.contentView!.bounds)
        startCountdown()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLabels(frame: CGRect) {
        guard let contentView = window?.contentView else { return }

        timerLabel = NSTextField(labelWithString: formatTime(countdown))
        timerLabel.font = .systemFont(ofSize: 120, weight: .bold)
        timerLabel.textColor = Settings.shared.breakTimerColor
        timerLabel.alignment = .center
        timerLabel.backgroundColor = .clear
        timerLabel.isBordered = false
        timerLabel.isEditable = false
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timerLabel)

        breakLabel = NSTextField(labelWithString: Settings.shared.breakMessage)
        breakLabel.font = .systemFont(ofSize: 48, weight: .medium)
        breakLabel.textColor = Settings.shared.breakMessageColor
        breakLabel.alignment = .center
        breakLabel.backgroundColor = .clear
        breakLabel.isBordered = false
        breakLabel.isEditable = false
        breakLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(breakLabel)

        NSLayoutConstraint.activate([
            timerLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            timerLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -60),
            timerLabel.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.9),
            breakLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            breakLabel.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 40),
            breakLabel.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.9),
        ])
    }

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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

    override func close() {
        timer?.invalidate()
        super.close()
    }
}
