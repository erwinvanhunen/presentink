//
//  SidebarButtonView.swift
//  PresentInker
//
//  Created by Erwin van Hunen on 2025-07-10.
//

import Cocoa

class SidebarButtonView: NSView {
    let iconView: NSImageView
    let label: NSTextField

    init(icon: NSImage?, title: String) {
        iconView = NSImageView(image: icon ?? NSImage())
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 16,
            weight: .regular
        )
        iconView.contentTintColor = .systemBlue
        iconView.translatesAutoresizingMaskIntoConstraints = false

        label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        super.init(frame: .zero)
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(equalToConstant: 12).isActive = true

        let stack = NSStackView(views: [spacer, iconView, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),  // Equal icon width
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
