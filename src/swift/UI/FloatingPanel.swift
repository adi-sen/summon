import Cocoa
import Combine
import SwiftUI

class FloatingPanel: NSPanel {
	private var cancellables = Set<AnyCancellable>()

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

		animationBehavior = .utilityWindow

		hidesOnDeactivate = false

		updateShadow()

		let settings = AppSettings.shared
		Publishers.CombineLatest(
			settings.$windowShadowOpacity,
			settings.$windowShadowRadius
		)
		.sink { [weak self] _, _ in
			self?.updateShadow()
		}
		.store(in: &cancellables)

		NotificationCenter.default.addObserver(
			forName: NSWindow.didResignKeyNotification,
			object: self,
			queue: .main
		) { [weak self] _ in
			self?.orderOut(nil)
		}
	}

	private func updateShadow() {
		let settings = AppSettings.shared
		hasShadow = settings.windowShadowOpacity > 0 && settings.windowShadowRadius > 0
		if hasShadow {
			invalidateShadow()
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
