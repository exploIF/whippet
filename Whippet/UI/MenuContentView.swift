import SwiftUI

struct MenuContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 32, height: 32)
                Text("Whippet")
                    .font(.headline)
                Spacer()
            }

            Text("Free up space taken by Xcode, Android, React Native and web build artifacts.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                Spacer()
                Button("Quit Whippet") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding()
        .frame(width: 360)
    }
}

#Preview {
    MenuContentView()
}
