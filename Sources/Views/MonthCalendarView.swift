import Foundation
import SwiftUI

struct MonthCalendarView: View {
	@Binding var selectedDate: Date

	@Environment(\.colorScheme) private var colorScheme

	private let calendar = Calendar.autoupdatingCurrent
	private static let monthTitleFormatter: DateFormatter = {
		let f = DateFormatter()
		f.locale = Locale(identifier: "ko_KR")
		f.timeZone = TimeZone.autoupdatingCurrent
		f.dateFormat = "yyyy년 M월"
		return f
	}()

	@State private var displayedMonthStart: Date

	init(selectedDate: Binding<Date>) {
		self._selectedDate = selectedDate
		let cal = Calendar.autoupdatingCurrent
		let start = cal.date(from: cal.dateComponents([.year, .month], from: selectedDate.wrappedValue)) ?? Date()
		self._displayedMonthStart = State(initialValue: start)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			header
			weekdayRow
			monthGrid
		}
		.onChange(of: selectedDate) { _, newValue in
			let start = calendar.date(from: calendar.dateComponents([.year, .month], from: newValue)) ?? newValue
			if !calendar.isDate(start, equalTo: displayedMonthStart, toGranularity: .month) {
				withAnimation(.snappy(duration: 0.25)) {
					displayedMonthStart = start
				}
			}
		}
	}

	private var header: some View {
		HStack(spacing: 10) {
			Text(monthTitle(for: displayedMonthStart))
				.font(.system(size: 16, weight: .bold, design: .rounded))
				.foregroundStyle(Theme.textPrimary(for: colorScheme))

			Spacer(minLength: 0)

			HStack(spacing: 8) {
				CalendarTodayButton {
					jumpToToday()
				}
				CalendarNavButton(systemName: "chevron.left") {
					shiftMonth(-1)
				}
				CalendarNavButton(systemName: "chevron.right") {
					shiftMonth(1)
				}
			}
		}
	}

	private var weekdayRow: some View {
		let symbols = orderedWeekdaySymbols()
		return HStack(spacing: 0) {
			ForEach(symbols, id: \.self) { s in
				Text(s)
					.font(.system(size: 11, weight: .semibold, design: .rounded))
					.foregroundStyle(Theme.textTertiary(for: colorScheme))
					.frame(maxWidth: .infinity)
			}
		}
		.padding(.vertical, 2)
	}

	private var monthGrid: some View {
		GeometryReader { geo in
			let spacing: CGFloat = 6
			let rawCell = floor((geo.size.width - (spacing * 6)) / 7.0)
			let cell = min(max(rawCell, 40), 66)

			let slots = daySlots(for: displayedMonthStart)
			let rows = max(1, Int(ceil(Double(slots.count) / 7.0)))
			let gridHeight = (cell * CGFloat(rows)) + (spacing * CGFloat(max(0, rows - 1)))

			LazyVGrid(
				columns: Array(repeating: GridItem(.fixed(cell), spacing: spacing), count: 7),
				spacing: spacing
			) {
				ForEach(slots.indices, id: \.self) { idx in
					if let date = slots[idx] {
						DayCell(
							day: calendar.component(.day, from: date),
							isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
							isToday: calendar.isDateInToday(date),
							onTap: {
								withAnimation(.snappy(duration: 0.25)) {
									selectedDate = date
								}
							}
						)
						.frame(width: cell, height: cell)
					} else {
						Color.clear
							.frame(width: cell, height: cell)
					}
				}
			}
			.frame(width: (cell * 7) + (spacing * 6), height: gridHeight, alignment: .topLeading)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
		.frame(minHeight: 380)
	}

	private func jumpToToday() {
		let today = Date()
		let start = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
		withAnimation(.snappy(duration: 0.22)) {
			selectedDate = today
			displayedMonthStart = start
		}
	}

	private func shiftMonth(_ delta: Int) {
		guard let next = calendar.date(byAdding: .month, value: delta, to: displayedMonthStart) else { return }
		let start = calendar.date(from: calendar.dateComponents([.year, .month], from: next)) ?? next
		withAnimation(.snappy(duration: 0.25)) {
			displayedMonthStart = start
		}
	}

	private func monthTitle(for date: Date) -> String {
		let f = Self.monthTitleFormatter
		f.calendar = calendar
		return f.string(from: date)
	}

	private func orderedWeekdaySymbols() -> [String] {
		// Very short symbols are best for a compact header row.
		let symbols = calendar.veryShortStandaloneWeekdaySymbols
		let startIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
		return Array(symbols[startIndex...] + symbols[..<startIndex])
	}

	private func daySlots(for monthStart: Date) -> [Date?] {
		let start = calendar.date(from: calendar.dateComponents([.year, .month], from: monthStart)) ?? monthStart
		let dayRange = calendar.range(of: .day, in: .month, for: start) ?? 1..<1

		let weekdayOfFirst = calendar.component(.weekday, from: start)
		let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

		var slots: [Date?] = Array(repeating: nil, count: leading)
		for day in dayRange {
			if let date = calendar.date(byAdding: .day, value: day - 1, to: start) {
				slots.append(date)
			}
		}
		while slots.count % 7 != 0 {
			slots.append(nil)
		}
		return slots
	}
}

private struct DayCell: View {
	let day: Int
	let isSelected: Bool
	let isToday: Bool
	let onTap: () -> Void

	@State private var isHovering = false

	var body: some View {
		Button(action: onTap) {
			ZStack {
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(backgroundFill)
					.overlay(
						RoundedRectangle(cornerRadius: 14, style: .continuous)
							.strokeBorder(borderStroke, lineWidth: isSelected ? 1.5 : 1)
					)

				Text("\(day)")
					.font(.system(size: 14, weight: .bold, design: .rounded))
					.foregroundStyle(textColor)
					.monospacedDigit()
			}
		}
		.buttonStyle(.plain)
		.onHover { hovering in
			withAnimation(.snappy(duration: 0.18)) {
				isHovering = hovering
			}
		}
	}

	private var backgroundFill: AnyShapeStyle {
		if isSelected {
			return AnyShapeStyle(
				LinearGradient(
					colors: [Theme.accent.opacity(0.95), Theme.warm.opacity(0.85)],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
			)
		}
		return AnyShapeStyle(Color.white.opacity(isHovering ? 0.14 : 0.08))
	}

	private var borderStroke: some ShapeStyle {
		if isSelected { return Color.white.opacity(0.30) }
		if isToday { return Theme.accent.opacity(0.75) }
		return Color.white.opacity(0.10)
	}

	private var textColor: Color {
		if isSelected { return Theme.ink }
		if isToday { return Color.white.opacity(0.95) }
		return Color.white.opacity(0.88)
	}
}

private struct CalendarNavButton: View {
	@Environment(\.colorScheme) private var colorScheme

	let systemName: String
	let action: () -> Void

	@State private var isHovering = false

	var body: some View {
		Button(action: action) {
			Image(systemName: systemName)
				.font(.system(size: 13, weight: .bold))
				.frame(width: 42, height: 42)
				.background(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(buttonFill)
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.strokeBorder(
									colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10),
									lineWidth: 1
								)
						)
				)
				.contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
		}
		.buttonStyle(.plain)
		.onHover { hovering in
			withAnimation(.snappy(duration: 0.18)) {
				isHovering = hovering
			}
		}
	}

	private var buttonFill: Color {
		if colorScheme == .dark {
			return Color.white.opacity(isHovering ? 0.16 : 0.10)
		}
		return Color.black.opacity(isHovering ? 0.10 : 0.06)
	}
}

private struct CalendarTodayButton: View {
	@Environment(\.colorScheme) private var colorScheme

	let action: () -> Void

	@State private var isHovering = false

	var body: some View {
		Button(action: action) {
			Text("오늘")
				.font(.system(size: 12, weight: .bold, design: .rounded))
				.frame(width: 56, height: 42)
				.background(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(buttonFill)
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.strokeBorder(
									colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10),
									lineWidth: 1
								)
						)
				)
				.contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
		}
		.buttonStyle(.plain)
		.help("오늘로 이동")
		.onHover { hovering in
			withAnimation(.snappy(duration: 0.18)) {
				isHovering = hovering
			}
		}
	}

	private var buttonFill: Color {
		if colorScheme == .dark {
			return Color.white.opacity(isHovering ? 0.16 : 0.10)
		}
		return Color.black.opacity(isHovering ? 0.10 : 0.06)
	}
}
