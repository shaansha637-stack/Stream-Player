import SwiftUI
import MobileVLCKit

final class PlayerController: ObservableObject {
    let player = VLCMediaPlayer()
    @Published var playing = true

    func play(_ url: URL) {
        player.media = VLCMedia(url: url)
        player.play()
        playing = true
    }

    func toggle() {
        if player.isPlaying {
            player.pause()
            playing = false
        } else {
            player.play()
            playing = true
        }
    }

    func back() { player.jumpBackward(10) }
    func forward() { player.jumpForward(10) }
    func stop() { player.stop() }
}

struct VLCView: UIViewRepresentable {
    let player: VLCMediaPlayer

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .black
        player.drawable = v
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct PlayerScreen: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @StateObject private var ctl = PlayerController()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VLCView(player: ctl.player).ignoresSafeArea()

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                }
                .padding()

                Spacer()

                HStack(spacing: 40) {
                    Button { ctl.back() } label: { Image(systemName: "gobackward.10") }
                    Button { ctl.toggle() } label: {
                        Image(systemName: ctl.playing ? "pause.fill" : "play.fill")
                    }
                    Button { ctl.forward() } label: { Image(systemName: "goforward.10") }
                }
                .font(.largeTitle)
                .foregroundColor(.white)
                .padding(.bottom, 30)
            }
        }
        .onAppear { ctl.play(url) }
        .onDisappear { ctl.stop() }
    }
}
