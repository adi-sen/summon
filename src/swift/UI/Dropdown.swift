import AppKit
import SwiftUI

class DropdownStateManager: ObservableObject {
	static let shared = DropdownStateManager()
	@Published var isAnyDropdownOpen = false

	private init() {}
}

struct Dropdown<T: Hashable>: View {
	let items: [T]
	@Binding var selection: T
	let label: (T) -> String
	@Binding var isExpanded: Bool
	let alignRight: Bool
	let width: CGFloat

	@ObservedObject var settings = AppSettings.shared
	@State private var panel: DropdownPanel?
	@State private var controller: Any?

	init(
		items: [T],
		selection: Binding<T>,
		label: @escaping (T) -> String,
		isExpanded: Binding<Bool>,
		alignRight: Bool = false,
		width: CGFloat = 180
	) {
		self.items = items
		self._selection = selection
		self.label = label
		self._isExpanded = isExpanded
		self.alignRight = alignRight
		self.width = width
	}

	var body: some View {
		HStack(spacing: 0) {
			DropdownButtonWrapper(
				label: label(selection),
				isExpanded: $isExpanded,
				settings: settings,
				onTap: { viewFrame in
					toggleDropdown(buttonViewFrame: viewFrame)
				}
			)
			.frame(height: 20)

			if alignRight {
				Spacer()
			}
		}
		.frame(maxWidth: .infinity, alignment: alignRight ? .trailing : .leading)
		.onReceive(NotificationCenter.default.publisher(for: .closeAllDropdowns)) { _ in
			closeDropdown()
		}
	}

	private func toggleDropdown(buttonViewFrame: NSRect) {
		if let panel, panel.isVisible {
			closeDropdown()
			return
		}

		isExpanded = true

		let controller = DropdownController(
			items: items,
			selection: $selection,
			label: label,
			settings: settings,
			width: width,
			onClose: { closeDropdown() }
		)

		let panel = DropdownPanel(
			contentRect: .zero,
			styleMask: [.borderless, .nonactivatingPanel],
			backing: .buffered,
			defer: false
		)
		panel.isOpaque = false
		panel.backgroundColor = .clear
		panel.hasShadow = false
		panel.level = .popUpMenu
		panel.contentView = controller.view

		// Use the content size stored in the controller (controller.view.frame gets reset to zero)
		let size = controller.contentSize

		// Position dropdown below the button using its actual screen frame
		// buttonViewFrame is already in screen coordinates (bottom-left origin)
		let dropdownY = buttonViewFrame.minY - size.height - 4

		// Align dropdown horizontally
		let xPosition: CGFloat = if alignRight {
			// Align right edge of dropdown with right edge of button
			buttonViewFrame.maxX - size.width
		} else {
			// Align left edge of dropdown with left edge of button
			buttonViewFrame.minX
		}

		let origin = NSPoint(x: xPosition, y: dropdownY)

		panel.setFrame(NSRect(origin: origin, size: size), display: true)
		panel.orderFront(nil)

		controller.panel = panel
		panel.onClickOutside = {
			DispatchQueue.main.async {
				NotificationCenter.default.post(name: .closeAllDropdowns, object: nil)
			}
		}

		self.panel = panel
		self.controller = controller
	}

	private func closeDropdown() {
		isExpanded = false
		panel?.close()
		panel = nil
		controller = nil
	}
}

class DropdownPanel: NSPanel {
	var onClickOutside: (() -> Void)?
	private var globalMonitor: Any?
	private var localMonitor: Any?

	override func orderFront(_ sender: Any?) {
		super.orderFront(sender)

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
			guard let self else { return }

			self.globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
				.leftMouseDown,
				.rightMouseDown
			]) { [weak self] _ in
				guard let self else { return }
				let mouseLocation = NSEvent.mouseLocation
				if !self.frame.contains(mouseLocation) {
					DispatchQueue.main.async {
						self.onClickOutside?()
					}
				}
			}

			self.localMonitor = NSEvent.addLocalMonitorForEvents(matching: [
				.leftMouseDown,
				.rightMouseDown
			]) { [weak self] event in
				guard let self else { return event }
				let mouseLocation = NSEvent.mouseLocation
				if !self.frame.contains(mouseLocation) {
					DispatchQueue.main.async {
						self.onClickOutside?()
					}
					return nil
				}
				return event
			}
		}
	}

	override func close() {
		if let globalMonitor {
			NSEvent.removeMonitor(globalMonitor)
			self.globalMonitor = nil
		}
		if let localMonitor {
			NSEvent.removeMonitor(localMonitor)
			self.localMonitor = nil
		}
		super.close()
	}

	override func cancelOperation(_ sender: Any?) {
		onClickOutside?()
	}
}

class DropdownController<T: Hashable>: NSViewController {
	let items: [T]
	let selection: Binding<T>
	let label: (T) -> String
	let settings: AppSettings
	let width: CGFloat
	let onClose: () -> Void
	var panel: NSPanel?
	var contentSize: CGSize = .zero

	init(
		items: [T],
		selection: Binding<T>,
		label: @escaping (T) -> String,
		settings: AppSettings,
		width: CGFloat,
		onClose: @escaping () -> Void
	) {
		self.items = items
		self.selection = selection
		self.label = label
		self.settings = settings
		self.width = width
		self.onClose = onClose
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func makeButton(for item: T, index: Int, itemHeight: CGFloat, padding: CGFloat) -> NSButton {
		let theme = settings.theme
		let font = settings.uiFont.withSize(13)
		let isSelected = item == selection.wrappedValue

		let button = HoverableMenuButton()
		button.isBordered = false
		button.bezelStyle = .rounded
		button.alignment = .left
		button.font = font
		button.target = self
		button.action = #selector(selectItem(_:))
		button.tag = index
		button.wantsLayer = true
		button.layer?.cornerRadius = 6
		button.translatesAutoresizingMaskIntoConstraints = false

		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .left
		paragraphStyle.firstLineHeadIndent = 12

		button.attributedTitle = NSAttributedString(
			string: label(item),
			attributes: [
				.font: font,
				.foregroundColor: UIUtils.makeColor(theme.textColor),
				.paragraphStyle: paragraphStyle
			]
		)

		button.theme = theme
		button.isSelected = isSelected

		if isSelected {
			button.layer?.backgroundColor = UIUtils.makeCGColor(theme.accentColor, alpha: 0.12)
		}

		NSLayoutConstraint.activate([
			button.heightAnchor.constraint(equalToConstant: itemHeight),
			button.widthAnchor.constraint(equalToConstant: width - padding * 2)
		])

		return button
	}

	override func loadView() {
		let theme = settings.theme
		let itemHeight: CGFloat = 36
		let spacing: CGFloat = 4
		let padding: CGFloat = 8
		let contentHeight = min(CGFloat(items.count) * (itemHeight + spacing) + padding * 2, 400)
		let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: contentHeight))

		let stackView = NSStackView()
		stackView.orientation = .vertical
		stackView.spacing = spacing
		stackView.alignment = .leading
		stackView.edgeInsets = NSEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
		stackView.translatesAutoresizingMaskIntoConstraints = false

		for (index, item) in items.enumerated() {
			stackView.addArrangedSubview(makeButton(for: item, index: index, itemHeight: itemHeight, padding: padding))
		}

		if items.count > 8 {
			let scrollView = NSScrollView(frame: contentView.bounds)
			scrollView.autoresizingMask = [.width, .height]
			scrollView.hasVerticalScroller = true
			scrollView.drawsBackground = false
			scrollView.documentView = stackView
			contentView.addSubview(scrollView)

			NSLayoutConstraint.activate([
				stackView.leadingAnchor.constraint(equalTo: scrollView.documentView!.leadingAnchor),
				stackView.trailingAnchor.constraint(equalTo: scrollView.documentView!.trailingAnchor),
				stackView.topAnchor.constraint(equalTo: scrollView.documentView!.topAnchor)
			])
		} else {
			contentView.addSubview(stackView)
			NSLayoutConstraint.activate([
				stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
				stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
				stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
				stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
			])
		}

		contentView.wantsLayer = true
		contentView.layer?.backgroundColor = UIUtils.makeCGColor(theme.backgroundColor)
		contentView.layer?.cornerRadius = 10
		contentView.layer?.borderWidth = 1
		contentView.layer?.borderColor = UIUtils.makeCGColor(theme.accentColor, alpha: 0.15)

		self.view = contentView
		self.contentSize = contentView.frame.size
	}

	@objc private func selectItem(_ sender: NSButton) {
		selection.wrappedValue = items[sender.tag]
		panel?.close()
		dismiss(nil)
		onClose()
	}
}

class HoverableMenuButton: NSButton {
	var theme: Theme?
	var isSelected: Bool = false
	private var trackingArea: NSTrackingArea?

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		setupLayer()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupLayer()
	}

	private func setupLayer() {
		wantsLayer = true
		layer?.masksToBounds = true
	}

	override func updateTrackingAreas() {
		super.updateTrackingAreas()

		if let trackingArea {
			removeTrackingArea(trackingArea)
		}

		let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
		trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
		addTrackingArea(trackingArea!)
	}

	override func mouseEntered(with event: NSEvent) {
		super.mouseEntered(with: event)
		guard let theme else { return }

		NSAnimationContext.runAnimationGroup { context in
			context.duration = 0.15
			context.allowsImplicitAnimation = true

			layer?.backgroundColor = NSColor(
				red: theme.accentColor.0,
				green: theme.accentColor.1,
				blue: theme.accentColor.2,
				alpha: isSelected ? 0.18 : 0.08
			).cgColor
		}
	}

	override func mouseExited(with event: NSEvent) {
		super.mouseExited(with: event)
		guard let theme else { return }

		NSAnimationContext.runAnimationGroup { context in
			context.duration = 0.15
			context.allowsImplicitAnimation = true

			layer?.backgroundColor = isSelected ? NSColor(
				red: theme.accentColor.0,
				green: theme.accentColor.1,
				blue: theme.accentColor.2,
				alpha: 0.12
			).cgColor : NSColor.clear.cgColor
		}
	}
}

struct DropdownButtonWrapper: NSViewRepresentable {
	let label: String
	@Binding var isExpanded: Bool
	let settings: AppSettings
	let onTap: (NSRect) -> Void

	func makeCoordinator() -> Coordinator {
		Coordinator(onTap: onTap)
	}

	func makeNSView(context: Context) -> DropdownButtonView {
		let view = DropdownButtonView()
		view.label = label
		view.settings = settings
		view.coordinator = context.coordinator
		return view
	}

	func updateNSView(_ nsView: DropdownButtonView, context: Context) {
		nsView.label = label
		nsView.isExpanded = isExpanded
		nsView.needsDisplay = true
	}

	class Coordinator {
		let onTap: (NSRect) -> Void

		init(onTap: @escaping (NSRect) -> Void) {
			self.onTap = onTap
		}
	}
}

class DropdownButtonView: NSView {
	var label: String = ""
	var isExpanded: Bool = false
	var settings: AppSettings = .shared
	weak var coordinator: DropdownButtonWrapper.Coordinator?

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		setupView()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupView()
	}

	private func setupView() {
		wantsLayer = true
	}

	override var acceptsFirstResponder: Bool {
		true
	}

	override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
		true
	}

	override func mouseDown(with event: NSEvent) {
		guard let window = self.window else { return }
		let frameInWindow = convert(bounds, to: nil)
		let frameInScreen = window.convertToScreen(frameInWindow)
		coordinator?.onTap(frameInScreen)
	}

	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)

		let theme = settings.theme
		let font = settings.uiFont.withSize(13)

		let labelString = NSAttributedString(
			string: label,
			attributes: [.font: font, .foregroundColor: UIUtils.makeColor(theme.textColor)]
		)
		labelString.draw(at: NSPoint(x: 0, y: (bounds.height - labelString.size().height) / 2))

		let chevronX = labelString.size().width + 4
		let chevronY = bounds.height / 2
		let chevronSize: CGFloat = 9

		let chevronPath = NSBezierPath()
		let yOffset: CGFloat = isExpanded ? 2 : -2
		let yMid: CGFloat = isExpanded ? -2 : 2
		chevronPath.move(to: NSPoint(x: chevronX, y: chevronY + yOffset))
		chevronPath.line(to: NSPoint(x: chevronX + chevronSize / 2, y: chevronY + yMid))
		chevronPath.line(to: NSPoint(x: chevronX + chevronSize, y: chevronY + yOffset))

		UIUtils.makeColor(theme.secondaryTextColor).setStroke()
		chevronPath.lineWidth = 1.5
		chevronPath.stroke()
	}

	override var intrinsicContentSize: NSSize {
		let labelAttributes: [NSAttributedString.Key: Any] = [
			.font: settings.uiFont.withSize(13)
		]
		let labelString = NSAttributedString(string: label, attributes: labelAttributes)
		let width = labelString.size().width + 4 + 9 + 20
		return NSSize(width: width, height: 20)
	}
}
