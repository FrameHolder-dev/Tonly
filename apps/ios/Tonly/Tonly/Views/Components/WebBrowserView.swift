import SwiftUI
import SafariServices

struct WebBrowserView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SafariView(url: url)
            .ignoresSafeArea()
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredBarTintColor = UIColor(red: 15/255, green: 15/255, blue: 15/255, alpha: 1)
        vc.preferredControlTintColor = UIColor(red: 0, green: 152/255, blue: 234/255, alpha: 1)
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
