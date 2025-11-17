import Foundation

final class Debouncer {
	private var workItem: DispatchWorkItem?
	private let delay: TimeInterval
	private let queue: DispatchQueue

	init(delay: TimeInterval, queue: DispatchQueue = .main) {
		self.delay = delay
		self.queue = queue
	}

	func debounce(_ action: @escaping () -> Void) {
		workItem?.cancel()
		let item = DispatchWorkItem(block: action)
		workItem = item
		queue.asyncAfter(deadline: .now() + delay, execute: item)
	}

	func cancel() {
		workItem?.cancel()
	}
}
