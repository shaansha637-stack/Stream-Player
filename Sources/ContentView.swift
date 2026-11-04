import SwiftUI

struct PlayItem: Identifiable {
    let id = UUID()
    let url: URL
}

enum LinkKind {
    case magnet, torrent, direct, social, invalid
}

func classify(_ text: String) -> LinkKind {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let l = t.lowercased()
    if l.hasPrefix("magnet:") { return .magnet }
    guard let u = URL(string: t), let scheme = u.scheme?.lowercased(),
          ["http", "https"].contains(scheme), let host = u.host?.lowercased() else {
        return .invalid
    }
    if u.path.lowercased().hasSuffix(".torrent") { return .torrent }
    let social = ["youtube.com", "youtu.be", "instagram.com", "facebook.com", "fb.watch",
                  "tiktok.com", "twitter.com", "x.com", "reddit.com", "vimeo.com"]
    if social.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return .social }
    return .direct
}

struct ContentView: View {
    @StateObject private var manager = DownloadManager()
    @State private var input = ""
    @State private var message: String?
    @State private var playItem: PlayItem?

    private var kind: LinkKind { classify(input) }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack {
                    TextField("Paste link here", text: $input)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("Paste") {
                        if let s = UIPasteboard.general.string { input = s; message = nil }
                    }
                }

                HStack(spacing: 12) {
                    Button { play() } label: {
                        Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button { download() } label: {
                        Label("Download", systemImage: "arrow.down.circle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)

                if let message = message {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                List {
                    ForEach(manager.items) { item in
                        DownloadRow(item: item) { url in playItem = PlayItem(url: url) }
                    }
                    .onDelete(perform: manager.remove)
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("LinkGet")
        }
        .navigationViewStyle(.stack)
        .fullScreenCover(item: $playItem) { item in
            PlayerScreen(url: item.url)
        }
    }

    private func play() {
        message = nil
        switch kind {
        case .direct:
            if let url = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)) {
                playItem = PlayItem(url: url)
            }
        case .magnet, .torrent:
            message = "Torrent streaming comes in phase 2."
        case .social:
            message = "Social media links come in phase 3."
        case .invalid:
            message = "That doesn't look like a valid link."
        }
    }

    private func download() {
        message = nil
        switch kind {
        case .direct:
            if let url = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)) {
                manager.start(url)
                input = ""
            }
        case .magnet, .torrent:
            message = "Torrent download comes in phase 2."
        case .social:
            message = "Social media links come in phase 3."
        case .invalid:
            message = "That doesn't look like a valid link."
        }
    }
}

struct DownloadRow: View {
    @ObservedObject var item: DownloadItem
    var onPlay: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name).lineLimit(2)
            switch item.state {
            case .running:
                ProgressView(value: item.progress)
                HStack {
                    Text("\(Int(item.progress * 100))%").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Button("Cancel") { item.task?.cancel() }.font(.caption)
                }
            case .finished:
                HStack {
                    Text("Saved in Files > LinkGet").font(.caption).foregroundColor(.green)
                    Spacer()
                    if let f = item.localURL {
                        Button("Play") { onPlay(f) }.font(.caption)
                    }
                }
            case .failed(let msg):
                Text("Failed: \(msg)").font(.caption).foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
