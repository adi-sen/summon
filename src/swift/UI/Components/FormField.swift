import SwiftUI

struct FormField<Content: View>: View {
	let label: String
	let labelStyle: LabelStyle
	let spacing: CGFloat
	let description: String?
	let content: Content
	@ObservedObject var settings = AppSettings.shared

	enum LabelStyle {
		case regular
		case uppercase
	}

	init(
		label: String,
		labelStyle: LabelStyle = .regular,
		spacing: CGFloat = DesignTokens.Spacing.sm,
		description: String? = nil,
		@ViewBuilder content: () -> Content
	) {
		self.label = label
		self.labelStyle = labelStyle
		self.spacing = spacing
		self.description = description
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: spacing) {
			Text(label)
				.font(Font(settings.uiFont
						.withSize(labelStyle == .uppercase ? DesignTokens.Typography.small : DesignTokens.Typography
							.small + 1)))
				.foregroundColor(
					labelStyle == .uppercase ? settings.secondaryTextColorUI : settings.textColorUI
				)
				.textCase(labelStyle == .uppercase ? .uppercase : nil)

			content

			if let description {
				Text(description)
					.font(Font(settings.uiFont.withSize(10)))
					.foregroundColor(settings.secondaryTextColorUI.opacity(0.7))
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}
}

extension FormField where Content == AnyView {
	init(
		label: String,
		labelStyle: LabelStyle = .regular,
		spacing: CGFloat = 6,
		placeholder: String = "",
		text: Binding<String>,
		settings: AppSettings = .shared,
		description: String? = nil,
		editable: Bool = true,
		onChange: (() -> Void)? = nil
	) {
		self.label = label
		self.labelStyle = labelStyle
		self.spacing = spacing
		self.description = description
		self.settings = settings

		if editable {
			self.content = AnyView(
				TextField(placeholder.isEmpty ? label : placeholder, text: text)
					.textFieldStyle(PlainTextFieldStyle())
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
					.foregroundColor(settings.textColorUI)
					.padding(DesignTokens.Spacing.md + 2)
					.background(settings.searchBarColorUI.opacity(0.5))
					.cornerRadius(labelStyle == .uppercase ? DesignTokens.CornerRadius.sm : DesignTokens.CornerRadius
						.md)
					.onChange(of: text.wrappedValue) { _ in
						onChange?()
					}
			)
		} else {
			self.content = AnyView(
				Text(text.wrappedValue)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
					.foregroundColor(settings.textColorUI)
					.textSelection(.enabled)
					.padding(DesignTokens.Spacing.md + 2)
					.frame(maxWidth: .infinity, alignment: .leading)
					.background(settings.searchBarColorUI.opacity(0.5))
					.cornerRadius(DesignTokens.CornerRadius.sm)
			)
		}
	}
}

struct FormFieldText: View {
	let label: String
	let labelStyle: FormField<AnyView>.LabelStyle
	let spacing: CGFloat
	let placeholder: String
	@Binding var text: String
	let settings: AppSettings
	let description: String?
	let editable: Bool
	let onChange: (() -> Void)?

	init(
		label: String,
		labelStyle: FormField<AnyView>.LabelStyle = .regular,
		spacing: CGFloat = DesignTokens.Spacing.sm,
		placeholder: String = "",
		text: Binding<String>,
		settings: AppSettings = .shared,
		description: String? = nil,
		hint: String? = nil,
		editable: Bool = true,
		onChange: (() -> Void)? = nil
	) {
		self.label = label
		self.labelStyle = labelStyle
		self.spacing = spacing
		self.placeholder = placeholder
		self._text = text
		self.settings = settings
		self.description = hint ?? description
		self.editable = editable
		self.onChange = onChange
	}

	var body: some View {
		FormField(
			label: label,
			labelStyle: labelStyle,
			spacing: spacing,
			placeholder: placeholder,
			text: $text,
			settings: settings,
			description: description,
			editable: editable,
			onChange: onChange
		)
	}
}
