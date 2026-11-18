import SwiftUI

struct ContentView: View {
    // Đọc version từ Info.plist để nhìn trên máy là biết đang chạy bản nào
    private let version: String = {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "v\(short) (\(build))"
    }()

    var body: some View {
        VStack(spacing: 12) {
            Text("Hello World")
                .font(.largeTitle)
                .bold()
            Text(version)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
