import SwiftUI
import AVFoundation
import UIKit

/// Lecteur vidéo (AVPlayerLayer) avec tick toutes les ~100 ms pour permettre
/// la "prise de photo en direct" depuis la frame courante. Tap = lecture/pause.
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    let onTick: (Double) -> Void

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.onTick = onTick
        view.startTicking()
        let tap = UITapGestureRecognizer(target: view, action: #selector(PlayerContainerView.handleTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.onTick = onTick
    }

    final class PlayerContainerView: UIView {
        var onTick: ((Double) -> Void)?
        private var ticker: Timer?

        let playerLayer = AVPlayerLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            playerLayer.videoGravity = .resizeAspect
            layer.addSublayer(playerLayer)
            backgroundColor = .black
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }

        func startTicking() {
            ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let player = self?.playerLayer.player else { return }
                self?.onTick?(player.currentTime().seconds)
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let player = playerLayer.player else { return }
            if player.rate == 0 {
                player.play()
            } else {
                player.pause()
            }
        }

        deinit {
            ticker?.invalidate()
        }
    }
}
