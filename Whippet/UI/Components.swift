import SwiftUI

struct RiskBadge: View {
    let risk: CleanupRisk

    var body: some View {
        Text(risk.title)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var color: Color {
        switch risk {
        case .safe: .green
        case .moderate: .orange
        case .caution: .red
        }
    }
}

extension Int64 {
    var fileSize: String { formatted(.byteCount(style: .file)) }
}

extension URL {
    var tildePath: String { (path as NSString).abbreviatingWithTildeInPath }
}
