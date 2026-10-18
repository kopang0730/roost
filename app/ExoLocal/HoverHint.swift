import SwiftUI

/// 悬停提示：鼠标停在控件上，窗口底部浮出一条说明。
/// 和系统 .help 并存——.help 慢（约 1 秒），这条几乎立刻出现。
extension View {
    func hoverHint(_ text: String, _ store: Store) -> some View {
        self.onHover { inside in
            if inside {
                store.hoverHint = text
            } else if store.hoverHint == text {
                store.hoverHint = nil
            }
        }
    }
}

struct HoverHintBar: View {
    let text: String?

    var body: some View {
        Group {
            if let text {
                HStack(spacing: 6) {
                    Image(systemName: "cursorarrow.rays").font(.caption2)
                    Text(text).font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.12), value: text)
        .allowsHitTesting(false)
    }
}
