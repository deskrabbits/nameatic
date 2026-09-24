import SwiftUI

/// Brief loading state shown while the batch's reference clip has its
/// audio level analyzed, before the rename screen (and playback) starts.
struct PreparingBatchView: View {
    var body: some View {
        VStack(spacing: 0) {
            WindowHeader(title: "New Batch") {
                EmptyView()
            } trailing: {
                EmptyView()
            }

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Analyzing audio…")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
