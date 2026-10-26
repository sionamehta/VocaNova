import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var model = WebModel()

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()

            // The web page lays itself out around the notch and home bar,
            // so it gets the whole screen.
            WebView(webView: model.webView)
                .ignoresSafeArea()
                .opacity(model.failed ? 0 : 1)

            if model.failed {
                OfflineView(retry: model.reload)
            } else if model.loading && !model.loadedOnce {
                ProgressView()
                    .tint(Color.accentColor)
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct OfflineView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Voca Nova")
                .font(.title2.weight(.semibold))
            Text("Voca Nova needs the internet to load. Check your Wi-Fi or data, then try again.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 0))
        }
        .padding(32)
    }
}
