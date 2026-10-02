import SwiftUI

/// A little screen with a toggle in each corner, like macOS's own Hot
/// Corners sheet.
struct CornerPicker: View {
    @Binding var corners: Set<Corner>

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [Color(nsColor: Palette.accent).opacity(0.55), Color(nsColor: Palette.deep)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            ForEach(Corner.allCases) { corner in
                CornerButton(corner: corner, on: corners.contains(corner)) {
                    if corners.contains(corner) { corners.remove(corner) } else { corners.insert(corner) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: corner.alignment)
            }
        }
        .frame(width: 220, height: 138)
    }
}

private struct CornerButton: View {
    let corner: Corner
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuarterCircle(corner: corner)
                .fill(on ? Color(nsColor: Palette.light) : Color.white.opacity(0.22))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel(corner.name)
        .accessibilityAddTraits(on ? .isSelected : [])
        .animation(.spring(duration: 0.3, bounce: 0.4), value: on)
        .scaleEffect(on ? 1 : 0.82, anchor: corner.unitPoint)
    }
}

/// A quarter disc filling a square from one of its corners.
struct QuarterCircle: Shape {
    let corner: Corner

    func path(in rect: CGRect) -> Path {
        // SwiftUI's y grows downward, so a top corner points inward along +y.
        let c = CGPoint(x: corner.sx > 0 ? rect.maxX : rect.minX, y: corner.sy > 0 ? rect.minY : rect.maxY)
        let ix = -corner.sx, iy = corner.sy
        var p = Path()
        p.move(to: c)
        for i in 0...32 {
            let a = Double.pi / 2 * Double(i) / 32
            p.addLine(to: CGPoint(x: c.x + ix * rect.width * CGFloat(cos(a)), y: c.y + iy * rect.height * CGFloat(sin(a))))
        }
        p.closeSubpath()
        return p
    }
}

extension Corner {
    var name: LocalizedStringResource {
        switch self {
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        }
    }

    var alignment: Alignment {
        switch self {
        case .topLeft: .topLeading
        case .topRight: .topTrailing
        case .bottomLeft: .bottomLeading
        case .bottomRight: .bottomTrailing
        }
    }

    var unitPoint: UnitPoint {
        switch self {
        case .topLeft: .topLeading
        case .topRight: .topTrailing
        case .bottomLeft: .bottomLeading
        case .bottomRight: .bottomTrailing
        }
    }
}
