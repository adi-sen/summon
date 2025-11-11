import SwiftUI

struct ExtensionTester: View {
	@Environment(\.presentationMode) var presentationMode
	@ObservedObject var settings = AppSettings.shared
	let extensionPath: String
	let manifest: ExtensionManifest

	@State private var testQuery = ""
	@State private var isRunning = false
	@State private var results: String = ""
	@State private var executionTime: TimeInterval = 0
	@State private var error: String?

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				VStack(alignment: .leading, spacing: 4) {
					Text("Test Extension: \(manifest.name)")
						.font(Font(settings.uiFont.withSize(16)))
						.foregroundColor(settings.textColorUI)
					Text("Keyword: \(manifest.keyword)")
						.font(Font(settings.uiFont.withSize(12)))
						.foregroundColor(settings.secondaryTextColorUI)
				}
				Spacer()
				Button(action: { presentationMode.wrappedValue.dismiss() }) {
					Image(systemName: "xmark.circle.fill")
						.font(.system(size: 18))
						.foregroundColor(settings.secondaryTextColorUI)
				}
				.buttonStyle(PlainButtonStyle())
			}
			.padding(16)
			.background(settings.backgroundColorUI)

			Divider().background(Color.white.opacity(0.1))

			VStack(alignment: .leading, spacing: 16) {
				VStack(alignment: .leading, spacing: 8) {
					Text("Test Query")
						.font(Font(settings.uiFont.withSize(12)))
						.foregroundColor(settings.textColorUI)

					HStack {
						TextField("Enter test query...", text: $testQuery)
							.textFieldStyle(PlainTextFieldStyle())
							.font(Font(settings.uiFont.withSize(13)))
							.foregroundColor(settings.textColorUI)
							.padding(10)
							.background(settings.searchBarColorUI)
							.cornerRadius(6)

						Button(action: runTest) {
							HStack(spacing: 6) {
								if isRunning {
									ProgressView()
										.scaleEffect(0.7)
										.frame(width: 12, height: 12)
								} else {
									Image(systemName: "play.fill")
										.font(.system(size: 12))
								}
								Text(isRunning ? "Running..." : "Run Test")
									.font(Font(settings.uiFont.withSize(12)))
							}
							.foregroundColor(Color.white)
							.padding(.horizontal, 16)
							.padding(.vertical, 10)
							.background(isRunning ? settings.secondaryTextColorUI : settings.accentColorUI)
							.cornerRadius(6)
						}
						.buttonStyle(PlainButtonStyle())
						.disabled(isRunning)
					}
				}

				if let error {
					HStack(spacing: 8) {
						Image(systemName: "exclamationmark.triangle.fill")
							.foregroundColor(Color.red)
						Text(error)
							.font(Font(settings.uiFont.withSize(11)))
							.foregroundColor(Color.red)
					}
					.padding(12)
					.frame(maxWidth: .infinity, alignment: .leading)
					.background(Color.red.opacity(0.1))
					.cornerRadius(6)
				}

				if !results.isEmpty {
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text("Results")
								.font(Font(settings.uiFont.withSize(12)))
								.foregroundColor(settings.textColorUI)
							Spacer()
							if executionTime > 0 {
								Text(String(format: "%.0fms", executionTime * 1000))
									.font(Font(settings.uiFont.withSize(11)))
									.foregroundColor(
										executionTime < 0.5 ? Color
											.green : (executionTime < 1.0 ? Color.orange : Color.red)
									)
									.padding(.horizontal, 8)
									.padding(.vertical, 4)
									.background(settings.searchBarColorUI)
									.cornerRadius(4)
							}
						}

						ScrollView {
							Text(results)
								.font(Font(NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)))
								.foregroundColor(settings.textColorUI)
								.frame(maxWidth: .infinity, alignment: .leading)
								.textSelection(.enabled)
						}
						.frame(height: 300)
						.padding(12)
						.background(settings.searchBarColorUI.opacity(0.5))
						.cornerRadius(6)
					}
				}
			}
			.padding(16)

			Spacer()
		}
		.frame(width: 600, height: 550)
		.background(settings.backgroundColorUI)
	}

	private func runTest() {
		isRunning = true
		error = nil
		results = ""
		executionTime = 0

		DispatchQueue.global(qos: .userInitiated).async {
			let startTime = Date()
			let scriptPath = (extensionPath as NSString).appendingPathComponent(manifest.script)

			let task = Process()
			task.executableURL = URL(fileURLWithPath: scriptPath)
			task.arguments = [testQuery]
			task.currentDirectoryURL = URL(fileURLWithPath: extensionPath)

			let outputPipe = Pipe()
			let errorPipe = Pipe()
			task.standardOutput = outputPipe
			task.standardError = errorPipe

			do {
				try task.run()

				let timeoutSeconds = 2.0
				var isTimeout = false

				DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) {
					if task.isRunning {
						task.terminate()
						isTimeout = true
					}
				}

				task.waitUntilExit()

				let endTime = Date()
				let execTime = endTime.timeIntervalSince(startTime)

				let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
				let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

				DispatchQueue.main.async {
					self.executionTime = execTime

					if isTimeout {
						self.error = "Script timed out after 2 seconds"
						self.isRunning = false
						return
					}

					let stderr = String(data: errorData, encoding: .utf8) ?? ""
					if task.terminationStatus != 0 {
						self.error = "Exit code \(task.terminationStatus)\(stderr.isEmpty ? "" : ": \(stderr)")"
						self.isRunning = false
						return
					}

					if let output = String(data: outputData, encoding: .utf8) {
						let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
						if trimmed.isEmpty {
							self.error = "Script produced no output\(stderr.isEmpty ? "" : ". Stderr: \(stderr)")"
							self.isRunning = false
							return
						}

						if let jsonData = output.data(using: .utf8),
						   let json = try? JSONSerialization.jsonObject(with: jsonData),
						   let prettyData = try? JSONSerialization.data(
						   	withJSONObject: json,
						   	options: [.prettyPrinted, .sortedKeys]
						   ),
						   let prettyString = String(data: prettyData, encoding: .utf8)
						{
							self.results = prettyString
						} else {
							self.results = output
							if !trimmed.starts(with: "{") {
								self.error = "Output is not valid JSON\(stderr.isEmpty ? "" : ". Stderr: \(stderr)")"
							}
						}
					} else {
						self.error = "Failed to read script output"
					}

					self.isRunning = false
				}
			} catch {
				DispatchQueue.main.async {
					self.error = "Failed to execute script: \(error.localizedDescription)"
					self.isRunning = false
				}
			}
		}
	}
}
