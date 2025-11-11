import SwiftUI

struct ExtensionCreator: View {
	@Environment(\.presentationMode) var presentationMode
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var actionManager = ActionManager.shared

	@State private var name = ""
	@State private var keyword = ""
	@State private var description = ""
	@State private var icon = "puzzlepiece.extension"
	@State private var scriptLanguage: ScriptLanguage = .bash
	@State private var template: ScriptTemplate = .search
	@State private var showError = false
	@State private var errorMessage = ""

	enum ScriptLanguage: String, CaseIterable {
		case bash = "Bash"
		case python = "Python"
		case applescript = "AppleScript"
		case javascript = "JavaScript (Node)"

		var fileExtension: String {
			switch self {
			case .bash: "sh"
			case .python: "py"
			case .applescript: "scpt"
			case .javascript: "js"
			}
		}

		var shebang: String {
			switch self {
			case .bash: "#!/usr/bin/env bash"
			case .python: "#!/usr/bin/env python3"
			case .applescript: "#!/usr/bin/osascript"
			case .javascript: "#!/usr/bin/env node"
			}
		}
	}

	enum ScriptTemplate: String, CaseIterable {
		case search = "Search/Filter"
		case action = "Action"
		case calculator = "Calculator/Converter"

		var description: String {
			switch self {
			case .search: "Search files, filter data, query APIs"
			case .action: "Open apps, run commands, copy text"
			case .calculator: "Calculate, convert units, format text"
			}
		}
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Create Extension")
					.font(Font(settings.uiFont.withSize(16)))
					.foregroundColor(settings.textColorUI)
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

			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					HStack(spacing: 12) {
						Image(systemName: "info.circle.fill")
							.font(.system(size: 14))
							.foregroundColor(settings.accentColorUI)
						VStack(alignment: .leading, spacing: 4) {
							Text("Script Filter Extensions")
								.font(Font(settings.uiFont.withSize(12)))
								.foregroundColor(settings.textColorUI)
							Text(
								"Creates a script-based extension. For high-performance native (Rust) extensions, see documentation."
							)
							.font(Font(settings.uiFont.withSize(11)))
							.foregroundColor(settings.secondaryTextColorUI)
							.fixedSize(horizontal: false, vertical: true)
						}
					}
					.padding(12)
					.background(settings.searchBarColorUI.opacity(0.3))
					.cornerRadius(8)

					VStack(alignment: .leading, spacing: 16) {
						FormFieldText(
							label: "Extension Name",
							placeholder: "e.g., Obsidian Workspace Switcher",
							text: $name,
							settings: settings
						)

						FormFieldText(
							label: "Trigger Keyword",
							placeholder: "e.g., ow",
							text: $keyword,
							settings: settings,
							hint: "Type this keyword to activate your extension"
						)

						FormFieldText(
							label: "Description",
							placeholder: "What does this extension do?",
							text: $description,
							settings: settings
						)

						FormFieldText(
							label: "Icon (SF Symbol)",
							placeholder: "e.g., puzzlepiece.extension",
							text: $icon,
							settings: settings,
							hint: "Browse SF Symbols online"
						)
					}

					Divider().background(Color.white.opacity(0.1))

					VStack(alignment: .leading, spacing: 12) {
						Text("Template Type")
							.font(Font(settings.uiFont.withSize(12)))
							.foregroundColor(settings.textColorUI)

						ForEach(ScriptTemplate.allCases, id: \.self) { tmpl in
							TemplateButton(
								template: tmpl,
								isSelected: template == tmpl,
								settings: settings,
								onSelect: { template = tmpl }
							)
						}
					}

					Divider().background(Color.white.opacity(0.1))

					VStack(alignment: .leading, spacing: 12) {
						Text("Script Language")
							.font(Font(settings.uiFont.withSize(12)))
							.foregroundColor(settings.textColorUI)

						HStack(spacing: 8) {
							ForEach(ScriptLanguage.allCases, id: \.self) { lang in
								Button(action: { scriptLanguage = lang }) {
									Text(lang.rawValue)
										.font(Font(settings.uiFont.withSize(12)))
										.foregroundColor(
											scriptLanguage == lang
												? Color.white : settings.textColorUI
										)
										.padding(.horizontal, 12)
										.padding(.vertical, 8)
										.background(
											scriptLanguage == lang
												? settings.accentColorUI
												: settings
												.searchBarColorUI
										)
										.cornerRadius(6)
								}
								.buttonStyle(PlainButtonStyle())
							}
						}
					}

					HStack(spacing: 10) {
						Image(systemName: "info.circle")
							.foregroundColor(settings.accentColorUI)
						VStack(alignment: .leading, spacing: 4) {
							Text("A starter script will be created for you")
								.font(Font(settings.uiFont.withSize(11)))
								.foregroundColor(settings.textColorUI)
							Text("You can customize it after creation")
								.font(Font(settings.uiFont.withSize(10)))
								.foregroundColor(settings.secondaryTextColorUI)
						}
						Spacer()
					}
					.padding(12)
					.background(settings.searchBarColorUI.opacity(0.5))
					.cornerRadius(6)
				}
				.padding(24)
			}

			Divider().background(Color.white.opacity(0.1))

			HStack(spacing: 12) {
				StyledButton("Cancel", style: .secondary) {
					presentationMode.wrappedValue.dismiss()
				}

				Spacer()

				Button(action: createExtension) {
					Text("Create Extension")
						.font(Font(settings.uiFont.withSize(13)))
						.foregroundColor(Color.white)
						.padding(.horizontal, 16)
						.padding(.vertical, 8)
						.background(isFormValid ? settings.accentColorUI : settings.searchBarColorUI)
						.cornerRadius(6)
				}
				.buttonStyle(PlainButtonStyle())
				.disabled(!isFormValid)
			}
			.padding(16)
			.background(settings.backgroundColorUI)
		}
		.frame(width: 520, height: 680)
		.background(settings.backgroundColorUI)
		.alert("Error", isPresented: $showError) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(errorMessage)
		}
	}

	var isFormValid: Bool {
		!name.isEmpty && !keyword.isEmpty
	}

	func createExtension() {
		let extensionId = keyword.lowercased().replacingOccurrences(of: " ", with: "-")
		let extensionsDir = StoragePathManager.shared.getExtensionsDir()
		let extensionDir = (extensionsDir as NSString).appendingPathComponent(extensionId)

		if FileManager.default.fileExists(atPath: extensionDir) {
			errorMessage = "An extension with keyword '\(keyword)' already exists"
			showError = true
			return
		}

		do {
			try FileManager.default.createDirectory(
				atPath: extensionDir, withIntermediateDirectories: true
			)
		} catch {
			errorMessage = "Failed to create extension directory: \(error.localizedDescription)"
			showError = true
			return
		}

		let manifest: [String: Any] = [
			"name": name,
			"description": description.isEmpty ? name : description,
			"author": NSFullUserName(),
			"version": "1.0.0",
			"keyword": keyword,
			"icon": icon,
			"script": "script.\(scriptLanguage.fileExtension)"
		]

		let manifestPath = (extensionDir as NSString).appendingPathComponent("manifest.json")
		do {
			let jsonData = try JSONSerialization.data(
				withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]
			)
			try jsonData.write(to: URL(fileURLWithPath: manifestPath))
		} catch {
			errorMessage = "Failed to create manifest: \(error.localizedDescription)"
			showError = true
			return
		}

		let scriptPath = (extensionDir as NSString).appendingPathComponent(
			"script.\(scriptLanguage.fileExtension)")
		let scriptContent = generateScript()

		do {
			try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)

			let attrs = [FileAttributeKey.posixPermissions: 0o755]
			try FileManager.default.setAttributes(attrs, ofItemAtPath: scriptPath)
		} catch {
			errorMessage = "Failed to create script: \(error.localizedDescription)"
			showError = true
			return
		}

		actionManager.load()

		NSWorkspace.shared.open(URL(fileURLWithPath: scriptPath))

		presentationMode.wrappedValue.dismiss()
	}

	func generateScript() -> String {
		switch scriptLanguage {
		case .bash:
			generateBashScript()
		case .python:
			generatePythonScript()
		case .applescript:
			generateAppleScript()
		case .javascript:
			generateJavaScriptScript()
		}
	}

	func generateBashScript() -> String {
		switch template {
		case .search:
			"""
			\(scriptLanguage.shebang)
			set -e

			# Get search query from argument
			query="$1"

			# TODO: Implement your search logic here
			# This example searches for files in your home directory

			# Start JSON output
			echo '{"items":['

			first=true
			while IFS= read -r file; do
			    [ "$first" = true ] && first=false || echo ","

			    basename=$(basename "$file")
			    echo "  {"
			    echo "    \\"title\\": \\"$basename\\","
			    echo "    \\"subtitle\\": \\"$file\\","
			    echo "    \\"arg\\": \\"$file\\""
			    echo -n "  }"
			done < <(find "$HOME" -name "*$query*" -maxdepth 3 -type f 2>/dev/null | head -10)

			echo
			echo ']}'
			"""

		case .action:
			"""
			\(scriptLanguage.shebang)
			set -e

			# Get input from argument
			input="$1"

			# TODO: Implement your action here
			# This example shows a simple text transformation

			result=$(echo "$input" | tr '[:lower:]' '[:upper:]')

			# Output JSON
			cat <<EOF
			{
			  "items": [
			    {
			      "title": "$result",
			      "subtitle": "Uppercase version",
			      "arg": "$result"
			    }
			  ]
			}
			EOF
			"""

		case .calculator:
			"""
			\(scriptLanguage.shebang)
			set -e

			# Get expression from argument
			expr="$1"

			# TODO: Implement your calculation here
			# This example uses bc for basic math

			if [ -z "$expr" ]; then
			    echo '{"items":[{"title":"Enter an expression","subtitle":"e.g., 2+2","valid":false}]}'
			    exit 0
			fi

			result=$(echo "$expr" | bc -l 2>/dev/null || echo "Error")

			cat <<EOF
			{
			  "items": [
			    {
			      "title": "$result",
			      "subtitle": "$expr = $result",
			      "arg": "$result"
			    }
			  ]
			}
			EOF
			"""
		}
	}

	func generatePythonScript() -> String {
		switch template {
		case .search:
			"""
			\(scriptLanguage.shebang)
			import sys
			import json
			import os
			from pathlib import Path

			def search(query):
			    \"\"\"TODO: Implement your search logic here\"\"\"
			    results = []

			    # Example: Search files in home directory
			    home = Path.home()
			    for path in home.rglob(f"*{query}*"):
			        if len(results) >= 10:
			            break
			        if path.is_file():
			            results.append({
			                "title": path.name,
			                "subtitle": str(path),
			                "arg": str(path)
			            })

			    return results

			if __name__ == "__main__":
			    query = sys.argv[1] if len(sys.argv) > 1 else ""
			    items = search(query)
			    print(json.dumps({"items": items}, indent=2))
			"""

		case .action:
			"""
			\(scriptLanguage.shebang)
			import sys
			import json

			def process(input_text):
			    \"\"\"TODO: Implement your action here\"\"\"
			    # Example: Uppercase transformation
			    result = input_text.upper()

			    return [{
			        "title": result,
			        "subtitle": "Uppercase version",
			        "arg": result
			    }]

			if __name__ == "__main__":
			    input_text = sys.argv[1] if len(sys.argv) > 1 else ""
			    items = process(input_text)
			    print(json.dumps({"items": items}, indent=2))
			"""

		case .calculator:
			"""
			\(scriptLanguage.shebang)
			import sys
			import json

			def calculate(expression):
			    \"\"\"TODO: Implement your calculation logic here\"\"\"
			    try:
			        result = eval(expression)
			        return [{
			            "title": str(result),
			            "subtitle": f"{expression} = {result}",
			            "arg": str(result)
			        }]
			    except:
			        return [{
			            "title": "Invalid expression",
			            "subtitle": "Try something like: 2+2",
			            "valid": False
			        }]

			if __name__ == "__main__":
			    expr = sys.argv[1] if len(sys.argv) > 1 else ""
			    if not expr:
			        items = [{"title": "Enter an expression", "subtitle": "e.g., 2+2", "valid": False}]
			    else:
			        items = calculate(expr)
			    print(json.dumps({"items": items}, indent=2))
			"""
		}
	}

	func generateAppleScript() -> String {
		"""
		\(scriptLanguage.shebang)
		-- Get query from argument
		on run argv
		    set query to item 1 of argv

		    -- TODO: Implement your script here

		    -- Example: Simple text response
		    set output to "{\\\"items\\\":[{\\\"title\\\":\\\"" & query & "\\\",\\\"subtitle\\\":\\\"You searched for this\\\"}]}"
		    return output
		end run
		"""
	}

	func generateJavaScriptScript() -> String {
		switch template {
		case .search:
			"""
			\(scriptLanguage.shebang)
			const query = process.argv[2] || '';

			const items = [];

			if (query) {
			    items.push({
			        title: `Search: ${query}`,
			        subtitle: 'Implement your search here',
			        arg: query
			    });
			}

			console.log(JSON.stringify({ items }, null, 2));
			"""

		case .action:
			"""
			\(scriptLanguage.shebang)
			const input = process.argv[2] || '';

			const result = input.toUpperCase();

			const items = [{
			    title: result,
			    subtitle: 'Uppercase version',
			    arg: result
			}];

			console.log(JSON.stringify({ items }, null, 2));
			"""

		case .calculator:
			"""
			\(scriptLanguage.shebang)
			const expr = process.argv[2] || '';

			let items = [];

			if (!expr) {
			    items = [{ title: 'Enter an expression', subtitle: 'e.g., 2+2', valid: false }];
			} else {
			    try {
			        const result = eval(expr);
			        items = [{
			            title: String(result),
			            subtitle: `${expr} = ${result}`,
			            arg: String(result)
			        }];
			    } catch (e) {
			        items = [{ title: 'Invalid expression', subtitle: e.message, valid: false }];
			    }
			}

			console.log(JSON.stringify({ items }, null, 2));
			"""
		}
	}
}

struct TemplateButton: View {
	let template: ExtensionCreator.ScriptTemplate
	let isSelected: Bool
	let settings: AppSettings
	let onSelect: () -> Void

	var body: some View {
		Button(action: onSelect) {
			HStack(spacing: 12) {
				Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
					.foregroundColor(
						isSelected ? settings.accentColorUI : settings.secondaryTextColorUI)

				VStack(alignment: .leading, spacing: 2) {
					Text(template.rawValue)
						.font(Font(settings.uiFont.withSize(13)))
						.foregroundColor(settings.textColorUI)
					Text(template.description)
						.font(Font(settings.uiFont.withSize(10)))
						.foregroundColor(settings.secondaryTextColorUI)
				}

				Spacer()
			}
			.padding(12)
			.background(
				isSelected ? settings.searchBarColorUI : settings.searchBarColorUI.opacity(0.3)
			)
			.cornerRadius(6)
		}
		.buttonStyle(PlainButtonStyle())
	}
}
