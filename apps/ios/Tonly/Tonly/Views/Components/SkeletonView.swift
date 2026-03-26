import SwiftUI

struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8
    @State private var opacity: Double = 0.3

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(TonlyTheme.surfaceLight)
            .frame(width: width, height: height)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 0.6
                }
            }
    }
}

struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView(width: 44, height: 44, cornerRadius: 22)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(width: 100, height: 14)
                SkeletonView(width: 60, height: 12)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                SkeletonView(width: 70, height: 14)
                SkeletonView(width: 50, height: 12)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, TonlyTheme.padding)
    }
}

struct SkeletonBalance: View {
    var body: some View {
        VStack(spacing: 10) {
            SkeletonView(width: 80, height: 14)
            SkeletonView(width: 180, height: 40, cornerRadius: 12)
            SkeletonView(width: 60, height: 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
