import Foundation
import SwiftUI

@MainActor
class ClipboardCoordinator: ObservableObject {
	@Published var clipboardHistory: [ClipboardEntry] = []
	@Published var clipboardPage = 0

	private let clipboardManager: ClipboardManager
	private let settings: AppSettings
	private let clipboardPageSize = 9

	init(clipboardManager: ClipboardManager, settings: AppSettings) {
		self.clipboardManager = clipboardManager
		self.settings = settings
	}

	func loadHistory() {
		clipboardHistory = clipboardManager.getHistory()
	}

	func createClipboardResults(searchQuery: String) -> [CategoryResult] {
		let currentTime = Date().timeIntervalSince1970
		let maxAge = Double(settings.clipboardRetentionDays) * 86400.0
		let filteredHistory = clipboardHistory.filter { entry in
			(currentTime - entry.timestamp) < maxAge
		}

		if searchQuery.isEmpty {
			return createPagedResults(from: filteredHistory)
		} else {
			return createFilteredResults(from: filteredHistory, query: searchQuery)
		}
	}

	func resetToFirstPage() {
		clipboardPage = 0
	}

	func loadNextPage() {
		clipboardPage += 1
	}

	func removeEntry(at index: Int) {
		clipboardManager.removeEntry(at: index)
		loadHistory()
	}

	private func createPagedResults(from history: [ClipboardEntry]) -> [CategoryResult] {
		let startIndex = clipboardPage * clipboardPageSize
		let endIndex = min(startIndex + clipboardPageSize, history.count)

		guard startIndex < history.count else {
			return []
		}

		let pageItems = Array(history[startIndex ..< endIndex])
		var results = pageItems.enumerated().map { index, entry in
			createClipboardResult(entry: entry, index: startIndex + index)
		}

		if endIndex < history.count {
			results.append(
				createLoadMoreResult(currentPage: clipboardPage, totalCount: history.count)
			)
		}

		return results
	}

	private func createFilteredResults(from history: [ClipboardEntry], query: String)
		-> [CategoryResult]
	{
		let lowercaseQuery = query.lowercased()
		let maxItems = settings.maxClipboardItems
		var matchCount = 0
		var filtered: [(Int, ClipboardEntry)] = []
		filtered.reserveCapacity(maxItems)

		for (index, entry) in history.enumerated() where matchCount < maxItems {
			if entry.content.lowercased().contains(lowercaseQuery)
				|| entry.displayName.lowercased().contains(lowercaseQuery)
			{
				filtered.append((index, entry))
				matchCount += 1
			}
		}

		return filtered.map { originalIndex, entry in
			createClipboardResult(entry: entry, index: originalIndex)
		}
	}

	private func createClipboardResult(entry: ClipboardEntry, index: Int) -> CategoryResult {
		let entryId = "clipboard_\(Int(entry.timestamp))_\(index)"
		return CategoryResult(
			id: entryId,
			name: entry.displayName,
			category: "Clipboard",
			path: nil,
			action: {
				let pasteboard = NSPasteboard.general
				pasteboard.clearContents()

				switch entry.type {
				case .text:
					pasteboard.setString(entry.content, forType: .string)
				case .image:
					entry.loadImageAndPaste(to: pasteboard)
				case .unknown:
					pasteboard.setString(entry.content, forType: .string)
				}

				NSApp.keyWindow?.orderOut(nil)
			},
			fullContent: nil,
			clipboardEntry: entry,
			icon: nil,
			score: Int64(1_000_000 - index)
		)
	}

	private func createLoadMoreResult(currentPage: Int, totalCount: Int) -> CategoryResult {
		let itemsShown = (currentPage + 1) * clipboardPageSize
		let remaining = totalCount - itemsShown

		return CategoryResult(
			id: "load_more",
			name: "Load \(min(remaining, clipboardPageSize)) more items...",
			category: "System",
			path: nil,
			action: nil,
			fullContent: nil,
			clipboardEntry: nil,
			icon: nil,
			score: -1
		)
	}
}
