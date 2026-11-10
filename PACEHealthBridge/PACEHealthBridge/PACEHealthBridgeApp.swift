import SwiftUI
import WebKit

@main
struct PACEHealthBridgeApp: App {
    var body: some Scene {
        WindowGroup {
            MainScreen()
        }
    }
}

@MainActor
final class BridgeController: ObservableObject {
    @Published var status = "佩戴 Apple Watch 训练后，点击「同步健康数据」"
    @Published var isSyncing = false

    weak var webView: WKWebView?
    private let reader = HealthKitReader()
    private var pendingEncodedSnapshot: String?

    func sync(days: Int = 7) {
        guard !isSyncing else { return }
        isSyncing = true
        status = "正在请求健康授权并读取最近\(days)天数据…"
        Task {
            defer { isSyncing = false }
            do {
                try await reader.requestAccess()
                let snapshot = try await reader.readRecent(days: days)
                let json = try JSONEncoder().encode(snapshot)
                pendingEncodedSnapshot = json.base64EncodedString()
                status = "已读取 \(snapshot.workouts.count) 条训练、\(snapshot.heartRate.count) 条心率和 \(snapshot.steps.count) 天步数。"
                sendToWebView()
            } catch {
                status = "同步未完成：\(error.localizedDescription)"
            }
        }
    }

    func webViewDidFinishLoading(_ webView: WKWebView) {
        self.webView = webView
        sendToWebView()
    }

    private func sendToWebView() {
        guard let webView, let pendingEncodedSnapshot else { return }
        // Base64 avoids JS injection and preserves all UTF-8 characters.
        // PACEBridge.receiveBase64 stores the snapshot in WKWebView's localStorage.
        let js = "window.PACEBridge && window.PACEBridge.receiveBase64('\(pendingEncodedSnapshot)')"
        webView.evaluateJavaScript(js) { [weak self] value, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.status = "网页尚未接收数据：\(error.localizedDescription)"
                    return
                }
                if (value as? Bool) == true {
                    self.pendingEncodedSnapshot = nil
                    self.status = "同步完成：数据已保存在本机 PACE，打开「Watch 分析」查看。"
                } else {
                    self.status = "网页尚未准备好，刷新页面后再点「同步健康数据」。"
                }
            }
        }
    }
}

struct MainScreen: View {
    @StateObject private var bridge = BridgeController()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("节律 PACE")
                        .font(.headline)
                    Text("Apple Watch / HealthKit 桥接")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    bridge.sync(days: 7)
                } label: {
                    HStack(spacing: 6) {
                        if bridge.isSyncing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "heart.text.square")
                        }
                        Text(bridge.isSyncing ? "同步中" : "同步健康数据")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(Color(red: 0.08, green: 0.37, blue: 0.32))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(bridge.isSyncing)
            }
            .padding(.horizontal, 15)
            .padding(.top, 10)
            .padding(.bottom, 7)
            .background(.regularMaterial)

            Text(bridge.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 15)
                .padding(.bottom, 7)
                .background(.regularMaterial)

            PACEWebView(bridge: bridge)
        }
    }
}
