import Foundation

final class FFIHandle<Handle> {
	private(set) var handle: Handle?
	private let freeFunc: (Handle?) -> Void

	init(create: () -> Handle?, free: @escaping (Handle?) -> Void) {
		self.handle = create()
		self.freeFunc = free
	}

	deinit {
		freeFunc(handle)
		handle = nil
	}
}
