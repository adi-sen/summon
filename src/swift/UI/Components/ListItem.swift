import SwiftUI

struct ListItem<TrailingContent: View>: View {
    let icon: ListItemIcon
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let isHovered: Binding<Bool>?
    let trailingContent: TrailingContent
    let action: (() -> Void)?
    @ObservedObject var settings = AppSettings.shared

    enum ListItemIcon {
        case sfSymbol(String, Color? = nil)
        case image(NSImage)
        case none

        var isSmall: Bool {
            false
        }
    }

    init(
        icon: ListItemIcon = .none,
        title: String,
        subtitle: String? = nil,
        isSelected: Bool = false,
        isHovered: Binding<Bool>? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder trailingContent: () -> TrailingContent
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.trailingContent = trailingContent()
        self.action = action
    }

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 12) {
                iconView
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font(settings.uiFont.withSize(13)))
                        .foregroundColor(settings.textColorUI)
                        .lineLimit(1)

                    if let subtitle {
                        Text(subtitle)
                            .font(Font(settings.uiFont.withSize(11)))
                            .foregroundColor(settings.secondaryTextColorUI)
                            .lineLimit(1)
                    }
                }

                Spacer()

                trailingContent
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundView)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered?.wrappedValue = hovering
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .sfSymbol(let name, let color):
            Image(systemName: name)
                .font(.system(size: 16))
                .foregroundColor(color ?? settings.accentColorUI)
        case .image(let image):
            Image(nsImage: image)
                .resizable()
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                isSelected
                    ? settings.accentColorUI.opacity(0.2)
                    : (isHovered?.wrappedValue == true ? settings.searchBarColorUI : Color.clear)
            )
    }
}

/// Convenience initializer with no trailing content
extension ListItem where TrailingContent == EmptyView {
    init(
        icon: ListItemIcon = .none,
        title: String,
        subtitle: String? = nil,
        isSelected: Bool = false,
        isHovered: Binding<Bool>? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.trailingContent = EmptyView()
        self.action = action
    }
}

/// Compact list item for simple cases (like folder rows)
struct CompactListItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onSecondaryAction: (() -> Void)?
    @ObservedObject var settings = AppSettings.shared
    @State private var isHovered = false

    init(
        icon: String,
        iconColor: Color = .blue,
        title: String,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onSecondaryAction = onSecondaryAction
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor.opacity(0.8))

                Text(title)
                    .font(Font(settings.uiFont.withSize(13)))
                    .foregroundColor(settings.textColorUI)

                Spacer()

                if let onSecondaryAction {
                    Button(action: onSecondaryAction) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(settings.secondaryTextColorUI)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? settings.accentColorUI.opacity(0.2)
                            : isHovered ? settings.searchBarColorUI : Color.clear
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
