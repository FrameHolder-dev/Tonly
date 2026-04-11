import SwiftUI
import AVKit
import WebKit

struct AnimatedImageView: View {
    let url: URL
    let staticFallback: URL?

    var body: some View {
        let ext = url.pathExtension.lowercased()
        if ext == "mp4" || ext == "mov" || ext == "m4v" || ext == "webm" {
            VideoPlayerView(url: url)
        } else if ext == "gif" || ext == "webp" {
            GIFView(url: url)
        } else if let fallback = staticFallback {
            AsyncImage(url: fallback) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
        } else {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
        }
    }
}

struct VideoPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIView {
        LoopingPlayerUIView(url: url)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

final class LoopingPlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer?
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?

    init(url: URL) {
        super.init(frame: .zero)
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        let looper = AVPlayerLooper(player: player, templateItem: item)
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        self.playerLayer = layer
        self.playerLooper = looper
        self.queuePlayer = player
        self.layer.addSublayer(layer)
        player.isMuted = true
        player.play()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}

struct GIFView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        let html = """
        <html><head><meta name='viewport' content='width=device-width,initial-scale=1'><style>
        html,body{margin:0;padding:0;background:transparent;height:100%;overflow:hidden}
        img{width:100%;height:100%;object-fit:cover;display:block}
        </style></head><body><img src="\(url.absoluteString)"></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
