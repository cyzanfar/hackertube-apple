import SwiftUI

/// Lays children out left to right, wrapping onto new lines (CSS `flex-wrap: wrap`).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat? = nil
    var alignment: VerticalAlignment = .center

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + CGFloat(max(0, rows.count - 1)) * (lineSpacing ?? spacing)
        return CGSize(width: proposal.width.map { min($0, width) } ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(bounds.width, subviews) {
            var x = bounds.minX
            for (index, size) in row.items {
                let dy: CGFloat = alignment == .top ? 0 : alignment == .bottom ? row.height - size.height : (row.height - size.height) / 2
                subviews[index].place(at: CGPoint(x: x, y: y + dy), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + (lineSpacing ?? spacing)
        }
    }

    private struct Row { var items: [(Int, CGSize)] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for (i, sub) in subviews.enumerated() {
            var size = sub.sizeThatFits(.unspecified)
            if size.width > maxWidth { size = sub.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil)) }
            let extra = rows[rows.count - 1].items.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > maxWidth && !rows[rows.count - 1].items.isEmpty {
                rows.append(Row())
            }
            let gap: CGFloat = rows[rows.count - 1].items.isEmpty ? 0 : spacing
            rows[rows.count - 1].items.append((i, size))
            rows[rows.count - 1].width += gap + size.width
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows.filter { !$0.items.isEmpty }
    }
}

/// Infinite-scroll paging over an offset-based endpoint, like the site's `infinite()`.
@MainActor @Observable
final class Pager {
    private(set) var items: [Video] = []
    private(set) var loading = false
    private(set) var done = false
    private(set) var error: String?
    private var offset = 0
    private var seen = Set<String>()
    let key: AnyHashable
    private let load: (Int) async throws -> [Video]

    init(key: AnyHashable, load: @escaping (Int) async throws -> [Video]) {
        self.key = key
        self.load = load
    }

    var started: Bool { offset > 0 || done }

    /// Loads the next page; detached from view lifetimes so navigating away doesn't cancel it.
    func more() {
        guard !loading, !done else { return }
        loading = true
        Task { @MainActor in
            do {
                let page = try await load(offset)
                offset += page.count
                done = page.isEmpty
                items += page.filter { seen.insert($0.vid).inserted }
            } catch {
                self.error = "Something went wrong (\(error.localizedDescription))."
                done = true
            }
            loading = false
        }
    }

    /// Call when an item appears: loads more as the end comes near.
    func appeared(_ v: Video) {
        if let i = items.lastIndex(of: v), i >= items.count - 8 { more() }
    }
}
