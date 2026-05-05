import SwiftUI

struct DefaultButton: View {
    @Binding var isEnabled: Bool

    var title: String
    var action: () -> Void

    init(
        _ title: String,
        isEnabled: Binding<Bool> = Binding<Bool>(get: { true }, set: { _ in }),
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self._isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(isEnabled ? .blue : .gray)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .disabled(!isEnabled)
    }
}
