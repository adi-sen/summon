import Cocoa
import SwiftUI

class FloatingPanel: NSPanel {
	init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
		super.init(
			contentRect: contentRect,
			styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
			backing: backing,
			defer: flag
		)

		isFloatingPanel = true
		level = .floating
		collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

		titleVisibility = .hidden
		titlebarAppearsTransparent = true
		isMovableByWindowBackground = true

		standardWindowButton(.closeButton)?.isHidden = true
		standardWindowButton(.miniaturizeButton)?.isHidden = true
		standardWindowButton(.zoomButton)?.isHidden = true

		backgroundColor = .clear
		isOpaque = false
		hasShadow = true

		animationBehavior = .utilityWindow

		hidesOnDeactivate = false

		NotificationCenter.default.addObserver(
			forName: NSWindow.didResignKeyNotification,
			object: self,
			queue: .main
		) { [weak self] _ in
			self?.orderOut(nil)
		}
	}

	override var canBecomeKey: Bool {
		true
	}

	override var canBecomeMain: Bool {
		false
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
}
