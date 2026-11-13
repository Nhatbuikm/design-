import SwiftUI
import WebKit
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    var body: some View {
        StudioWebView()
            .background(Color(red: 16/255, green: 17/255, blue: 22/255))
    }
}

struct StudioWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let controller = config.userContentController
        if let data = try? Data(contentsOf: context.coordinator.projectURL), data.count <= 24_000_000 {
            let encoded = data.base64EncodedString()
            let source = "window.buinhatSavedProject = new TextDecoder().decode(Uint8Array.from(atob('\(encoded)'), c => c.charCodeAt(0)));"
            controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        controller.add(context.coordinator, name: "studio")
        let view = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = view
        view.uiDelegate = context.coordinator
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = UIColor(red: 16/255, green: 17/255, blue: 22/255, alpha: 1)
        view.scrollView.backgroundColor = view.backgroundColor
        view.scrollView.bounces = false
        view.scrollView.contentInsetAdjustmentBehavior = .never
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            context.coordinator.editorURL = url
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            view.loadHTMLString("<h1>Không tìm thấy trình thiết kế.</h1>", baseURL: nil)
        }
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "studio")
    }

    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler, UIDocumentPickerDelegate {
        weak var webView: WKWebView?
        var editorURL: URL?
        private enum Pick { case project, image(String) }
        private var pendingPick: Pick?
        var projectURL: URL {
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("BuinhatStudio", isDirectory: true)
                .appendingPathComponent("CurrentProject.json")
        }

        private func call(_ code: String, _ arguments: [String: Any]) {
            webView?.callAsyncJavaScript(code, arguments: arguments, in: nil, in: .page) { _ in }
        }
        private func status(_ message: String, saved: Bool? = nil) {
            let value: Any = saved.map { $0 as Any } ?? NSNull()
            call("window.studioNativeStatus(message, saved)", ["message": message, "saved": value])
        }
        private func presenter() -> UIViewController? {
            var top = webView?.window?.rootViewController
            while let next = top?.presentedViewController { top = next }
            return top
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "studio", message.frameInfo.isMainFrame,
                  let body = message.body as? [String: Any], let kind = body["kind"] as? String else { return }
            switch kind {
            case "save":
                guard let raw = body["data"] as? String, raw.utf8.count <= 24_000_000 else {
                    status("Dự án quá lớn. Hãy lưu JSON để sao lưu.", saved: false); return
                }
                do {
                    try FileManager.default.createDirectory(at: projectURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try Data(raw.utf8).write(to: projectURL, options: .atomic)
                    status("", saved: true)
                } catch { status("Không lưu được dự án: \(error.localizedDescription)", saved: false) }
            case "export":
                guard let name = body["name"] as? String, let raw = body["data"] as? String,
                      ["Buinhat-website.html", "Buinhat-project.json"].contains(name), raw.utf8.count <= 64_000_000 else {
                    status("Tệp xuất không hợp lệ hoặc quá lớn."); return
                }
                share(name: name, data: Data(raw.utf8))
            case "pickJSON": pick(.project)
            case "pickImage":
                if let target = body["target"] as? String, !target.isEmpty { pick(.image(target)) }
            default: break
            }
        }
        private func pick(_ mode: Pick) {
            guard pendingPick == nil, let top = presenter() else { return }
            let types: [UTType]
            switch mode {
            case .project: types = [.json]
            case .image: types = [.png, .jpeg, .gif, UTType(filenameExtension: "webp") ?? .image]
            }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            picker.allowsMultipleSelection = false
            picker.delegate = self
            pendingPick = mode
            top.present(picker, animated: true)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { pendingPick = nil }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let mode = pendingPick else { return }
            pendingPick = nil
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let values = try url.resourceValues(forKeys: [.fileSizeKey])
                let limit: Int
                switch mode { case .project: limit = 12_000_000; case .image: limit = 3_000_000 }
                guard (values.fileSize ?? 0) <= limit else { status("Tệp vượt giới hạn dung lượng."); return }
                let data = try Data(contentsOf: url)
                guard data.count <= limit else { status("Tệp vượt giới hạn dung lượng."); return }
                switch mode {
                case .project:
                    guard let raw = String(data: data, encoding: .utf8) else { status("JSON phải dùng mã UTF-8."); return }
                    call("window.studioNativeImportJSON(raw)", ["raw": raw])
                case .image(let target):
                    let ext = url.pathExtension.lowercased()
                    let mime = ["png":"png", "jpg":"jpeg", "jpeg":"jpeg", "webp":"webp", "gif":"gif"][ext]
                    guard let mime = mime else { status("Chỉ hỗ trợ PNG, JPEG, WebP và GIF."); return }
                    call("window.studioNativeImportImage(data, target)", ["data": "data:image/\(mime);base64,\(data.base64EncodedString())", "target": target])
                }
            } catch { status("Không đọc được tệp: \(error.localizedDescription)") }
        }
        private func share(name: String, data: Data) {
            guard let top = presenter() else { status("Không mở được bảng chia sẻ."); return }
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(name)
                try data.write(to: url, options: .atomic)
                let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let pop = sheet.popoverPresentationController {
                    pop.sourceView = top.view
                    pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
                    pop.permittedArrowDirections = []
                }
                sheet.completionWithItemsHandler = { [weak self] _, completed, _, error in
                    if let error = error { self?.status("Không xuất được: \(error.localizedDescription)") }
                    else if completed { self?.status("Đã chia sẻ tệp.") }
                    try? FileManager.default.removeItem(at: dir)
                }
                top.present(sheet, animated: true)
            } catch { status("Không tạo được tệp: \(error.localizedDescription)") }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if url == editorURL || url.scheme == "about" { decisionHandler(.allow) }
            else { decisionHandler(.cancel) }
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard let url = navigationAction.request.url, ["https", "http"].contains(url.scheme ?? ""), let top = presenter() else { return nil }
            let alert = UIAlertController(title: "Mở liên kết?", message: url.absoluteString, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
            alert.addAction(UIAlertAction(title: "Mở Safari", style: .default) { _ in UIApplication.shared.open(url) })
            top.present(alert, animated: true)
            return nil
        }
    }
}
