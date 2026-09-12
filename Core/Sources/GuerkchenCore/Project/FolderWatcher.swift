import Foundation
import CoreServices

/// Beobachtet einen Ordner rekursiv per FSEvents und ruft `onChange` auf dem Main-Thread.
@MainActor
public final class FolderWatcher {
    private let url: URL
    private let latency: TimeInterval
    private let onChange: @MainActor () -> Void
    private var stream: FSEventStreamRef?

    public init(url: URL, latency: TimeInterval = 0.5, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.latency = latency
        self.onChange = onChange
    }

    isolated deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    public func start() {
        guard stream == nil else { return }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil)

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.onChange() }
        }

        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context,
            [url.path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency, flags)
        else { return }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
