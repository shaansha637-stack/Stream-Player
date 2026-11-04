import Foundation

enum DownloadState {
    case running
    case finished
    case failed(String)
}

final class DownloadItem: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL
    @Published var name: String
    @Published var progress: Double = 0
    @Published var state: DownloadState = .running
    @Published var localURL: URL?
    var task: URLSessionDownloadTask?

    init(url: URL) {
        self.url = url
        let last = url.lastPathComponent
        self.name = last.isEmpty ? (url.host ?? "file") : last
    }
}

final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var items: [DownloadItem] = []

    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func start(_ url: URL) {
        let item = DownloadItem(url: url)
        let task = session.downloadTask(with: url)
        item.task = task
        items.insert(item, at: 0)
        task.resume()
    }

    func remove(at offsets: IndexSet) {
        for i in offsets {
            let item = items[i]
            item.task?.cancel()
            if let f = item.localURL { try? FileManager.default.removeItem(at: f) }
        }
        items.remove(atOffsets: offsets)
    }

    private func item(for task: URLSessionTask) -> DownloadItem? {
        items.first { $0.task?.taskIdentifier == task.taskIdentifier }
    }

    private func uniqueURL(_ name: String) -> URL {
        let clean = name.replacingOccurrences(of: "/", with: "_")
        var dest = Self.documents.appendingPathComponent(clean)
        let base = dest.deletingPathExtension().lastPathComponent
        let ext = dest.pathExtension
        var n = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            let newName = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            dest = Self.documents.appendingPathComponent(newName)
            n += 1
        }
        return dest
    }

    // MARK: URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let item = item(for: downloadTask), totalBytesExpectedToWrite > 0 else { return }
        item.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let item = item(for: downloadTask) else { return }
        let suggested = downloadTask.response?.suggestedFilename ?? item.name
        let dest = uniqueURL(suggested)
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            item.name = dest.lastPathComponent
            item.localURL = dest
            item.progress = 1
            item.state = .finished
        } catch {
            item.state = .failed(error.localizedDescription)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error, let item = item(for: task) else { return }
        if case .running = item.state {
            item.state = .failed(error.localizedDescription)
        }
    }
}
