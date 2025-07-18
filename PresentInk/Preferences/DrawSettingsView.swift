//
//  DrawSettingsView.swift
//  PresentInker
//
//  Created by Erwin van Hunen on 2025-07-10.
//
import Cocoa

class DrawSettingsView: NSView {
    // Section label
    let sectionLabel: NSTextField = {
        let label = NSTextField(labelWithString: "DRAWING")
        label.font = NSFont.boldSystemFont(ofSize: 12)
        label.textColor = NSColor.secondaryLabelColor
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }()

    // Color options
    let colors: [NSColor] = [
        .red, .green, .blue,
        .yellow,
        .orange, NSColor.init(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0),
    ]
    var selectedColorIndex: Int = 3 {
        didSet { updateColorSelection() }
    }
    var colorButtons: [NSButton] = []

    // Pen width
    let penWidthLabel = NSTextField(labelWithString: "Pen width")
    let penWidthSlider = NSSlider(
        value: 7,
        minValue: 1,
        maxValue: 24,
        target: nil,
        action: nil
    )
    let penWidthValueLabel = NSTextField(labelWithString: "7")
    let penPreview = PenPreviewView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let configuredPenWidth = Settings.shared.penWidth
        penWidthSlider.integerValue = configuredPenWidth
        penWidthValueLabel.stringValue = "\(configuredPenWidth)"
        penPreview.penWidth = CGFloat(configuredPenWidth)

        let savedColor = Settings.shared.defaultColor
        if let colorIndex = colors.firstIndex(of: savedColor) {
            selectedColorIndex = colorIndex
            penPreview.penColor = savedColor
        } else {
            // Fallback to default if saved color not found
            selectedColorIndex = 3
            penPreview.penColor = colors[selectedColorIndex]
        }
        // Color row
        let colorLabel = NSTextField(labelWithString: "Default color")
        colorLabel.font = NSFont.systemFont(ofSize: 12)
        colorLabel.textColor = .labelColor

        let colorStack = NSStackView()
        colorStack.orientation = .horizontal
        colorStack.spacing = 24
        colorStack.alignment = .centerY

        for (i, color) in colors.enumerated() {
            let button = ColorCircleButton(color: color)
            button.target = self
            button.action = #selector(colorButtonClicked(_:))
            button.tag = i
            colorButtons.append(button)
            colorStack.addArrangedSubview(button)
        }
        updateColorSelection()

        //        let colorRow = NSStackView(views: [colorLabel, colorStack])
        //        colorRow.orientation = .horizontal
        //        colorRow.alignment = .centerY
        //        colorRow.spacing = 32

        // Pen width row
        penWidthLabel.font = NSFont.systemFont(ofSize: 12)
        penWidthLabel.textColor = .labelColor
        penWidthSlider.target = self
        penWidthSlider.action = #selector(penWidthChanged(_:))
        penWidthSlider.widthAnchor.constraint(equalToConstant: 160).isActive =
            true
        penWidthValueLabel.font = NSFont.monospacedDigitSystemFont(
            ofSize: 15,
            weight: .regular
        )
        penWidthValueLabel.textColor = .secondaryLabelColor
        penWidthValueLabel.alignment = .right
        penWidthValueLabel.isBezeled = false
        penWidthValueLabel.drawsBackground = false
        penWidthValueLabel.isEditable = false
        penWidthValueLabel.isSelectable = false
        penPreview.widthAnchor.constraint(equalToConstant: 56).isActive = true
        penPreview.heightAnchor.constraint(equalToConstant: 24).isActive = true
        penPreview.penColor = colors[selectedColorIndex]
        penPreview.penWidth = CGFloat(penWidthSlider.integerValue)

        let penWidthStack = NSStackView(views: [penWidthSlider, penPreview, penWidthValueLabel])
        penWidthStack.orientation = .horizontal
        penWidthStack.alignment = .centerY
        penWidthStack.spacing = 16
        //
        //        let penRow = NSStackView(views: [
        //            penWidthLabel, penWidthSlider, penWidthValueLabel, penPreview,
        //        ])
        //        penRow.orientation = .horizontal
        //        penRow.alignment = .centerY
        //        penRow.spacing = 16

        let grid = NSGridView(views: [
            [colorLabel, colorStack],
            [penWidthLabel, penWidthStack],
        ])
        grid.rowSpacing = 16
        grid.columnSpacing = 32
        grid.translatesAutoresizingMaskIntoConstraints = false
        for row in 0..<grid.numberOfRows {
            for col in 0..<grid.numberOfColumns {
                grid.cell(atColumnIndex: col, rowIndex: row).yPlacement = .center
            }
        }
        // Main stack
//        let stack = NSStackView(views: [sectionLabel, colorRow, penRow])
        let stack = NSStackView(views: [
            sectionLabel,
            grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            stack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 32
            ),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -32
            ),
            stack.bottomAnchor.constraint(
                lessThanOrEqualTo: bottomAnchor,
                constant: -32
            ),
        ])

    }

    @objc func colorButtonClicked(_ sender: NSButton) {
        selectedColorIndex = sender.tag
        penPreview.penColor = colors[selectedColorIndex]
        Settings.shared.defaultColor = colors[selectedColorIndex]
        penPreview.needsDisplay = true
    }

    func updateColorSelection() {
        for (i, button) in colorButtons.enumerated() {
            (button as? ColorCircleButton)?.isSelected =
                (i == selectedColorIndex)
        }
    }

    @objc func penWidthChanged(_ sender: NSSlider) {
        let value = sender.integerValue
        penWidthValueLabel.stringValue = "\(value)"
        penPreview.penWidth = CGFloat(value)
        Settings.shared.penWidth = value
        penPreview.needsDisplay = true

    }

    required init?(coder: NSCoder) { fatalError() }
}

class PenPreviewView: NSView {
    var penColor: NSColor = .systemYellow
    var penWidth: CGFloat = 7

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath()
        let y = bounds.midY
        path.move(to: NSPoint(x: 8, y: y))
        path.line(to: NSPoint(x: bounds.width - 8, y: y))
        penColor.setStroke()
        path.lineWidth = penWidth
        path.lineCapStyle = .round
        path.stroke()
    }
}

class ColorCircleButton: NSButton {
    let color: NSColor
    var isSelected: Bool = false { didSet { needsDisplay = true } }

    init(color: NSColor) {
        self.color = color
        super.init(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        bezelStyle = .shadowlessSquare
        isBordered = false
        wantsLayer = true
        setButtonType(.momentaryChange)
        focusRingType = .none
        widthAnchor.constraint(equalToConstant: 32).isActive = true
        heightAnchor.constraint(equalToConstant: 32).isActive = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let diameter = min(bounds.width, bounds.height) - 8
        let circleRect = NSRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )

        color.setFill()
        let path = NSBezierPath(ovalIn: circleRect)
        path.fill()

        if isSelected {
            if let checkImage = NSImage(
                systemSymbolName: "checkmark",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            ) {
                let checkRect = NSRect(
                    x: circleRect.midX - 6,
                    y: circleRect.midY - 6,
                    width: 12,
                    height: 12
                )
                NSGraphicsContext.saveGraphicsState()
                let context = NSGraphicsContext.current?.cgContext
                context?.setBlendMode(.sourceAtop)
                NSColor.white.set()
                checkImage.draw(
                    in: checkRect,
                    from: .zero,
                    operation: .sourceAtop,
                    fraction: 1.0,
                    respectFlipped: true,
                    hints: nil
                )
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }

    required init?(coder: NSCoder) { fatalError() }
}
