import Carbon
import Cocoa

class HotKeyMonitor {
	private var eventHandler: EventHandlerRef?
	private var hotKeys: [(id: UInt32, ref: EventHotKeyRef?, callback: () -> Void)] = []
	private var nextID: UInt32 = 1

	func registerHotKey(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
		var hotKeyID = EventHotKeyID()
		hotKeyID.signature = OSType("LNCH".fourCharCodeValue)
		hotKeyID.id = nextID

		var hotKeyRef: EventHotKeyRef?
		let status = RegisterEventHotKey(
			keyCode,
			modifiers,
			hotKeyID,
			GetApplicationEventTarget(),
			0,
			&hotKeyRef
		)

		if status == noErr {
			hotKeys.append((id: nextID, ref: hotKeyRef, callback: callback))
			nextID += 1
		}
	}

	func unregisterAllHotKeys() {
		for hotKey in hotKeys {
			if let ref = hotKey.ref {
				UnregisterEventHotKey(ref)
			}
		}
		hotKeys.removeAll()
	}

	func setupEventHandler() {
		var eventType = EventTypeSpec()
		eventType.eventClass = OSType(kEventClassKeyboard)
		eventType.eventKind = OSType(kEventHotKeyPressed)

		InstallEventHandler(
			GetApplicationEventTarget(),
			{ _, event, userData -> OSStatus in
				guard let userData else { return noErr }
				let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()

				var hotKeyID = EventHotKeyID()
				GetEventParameter(
					event,
					EventParamName(kEventParamDirectObject),
					EventParamType(typeEventHotKeyID),
					nil,
					MemoryLayout<EventHotKeyID>.size,
					nil,
					&hotKeyID
				)

				if let hotKey = monitor.hotKeys.first(where: { $0.id == hotKeyID.id }) {
					hotKey.callback()
				}

				return noErr
			},
			1,
			&eventType,
			UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
			&eventHandler
		)
	}

	deinit {
		if let handler = eventHandler {
			RemoveEventHandler(handler)
		}
	}
}

extension String {
	var fourCharCodeValue: Int {
		var result = 0
		for char in utf8 {
			result = result << 8 + Int(char)
		}
		return result
	}
}
