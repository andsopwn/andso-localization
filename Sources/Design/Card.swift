import SwiftUI

struct Card<Content: View, Trailing: View>: View {
	@Environment(\.colorScheme) private var colorScheme

	private let title: String
	private let trailing: Trailing
	private let content: Content

	init(_ title: String, @ViewBuilder trailing: () -> Trailing, @ViewBuilder content: () -> Content) {
		self.title = title
		self.trailing = trailing()
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(alignment: .firstTextBaseline, spacing: 12) {
				Text(title)
					.font(.system(size: 18, weight: .semibold, design: .rounded))
				Spacer(minLength: 0)
				trailing
			}
			content
		}
		.padding(16)
		.background(
			RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
				.fill(Theme.sectionFill(for: colorScheme))
				.overlay(
					RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
						.strokeBorder(
							colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.12),
							lineWidth: 1
						)
				)
				.shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 8)
		)
	}
}

extension Card where Trailing == EmptyView {
	init(_ title: String, @ViewBuilder content: () -> Content) {
		self.init(title, trailing: { EmptyView() }, content: content)
	}
}
