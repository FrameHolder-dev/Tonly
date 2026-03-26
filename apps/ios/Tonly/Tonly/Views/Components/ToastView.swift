import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TonlyTheme.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(TonlyTheme.surface)
        .clipShape(Capsule())
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String
    let color: Color

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if isPresented {
                ToastView(message: message, icon: icon, color: color)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isPresented = false
                            }
                        }
                    }
            }
        }
        .animation(.easeOut(duration: 0.3), value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill", color: Color = TonlyTheme.success) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, icon: icon, color: color))
    }
}
