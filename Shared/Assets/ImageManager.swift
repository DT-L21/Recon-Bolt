import SwiftUI
import HandyOperators
import UserDefault

@MainActor
final class ImageManager: ObservableObject {
	@UserDefault("ImageManager.version")
	private static var version = ""
	
	@Published private var states: [AssetImage: ImageState] = [:]
	// caching these helps a lot with performance
	// nil means image loading was attempted but failed
	private var cached: [AssetImage: Image?] = [:]
	private var inProgress: Set<AssetImage> = []
	private let client = AssetClient()
	
	nonisolated init() {
		Task { @MainActor in
			Self.version = try await client.getCurrentVersion().riotClientVersion
		}
	}
	
	func setVersion(_ version: AssetVersion) {
		Self.version = version.riotClientVersion
		// TODO: invalidate images?
	}
	
	func state(for image: AssetImage) -> ImageState? {
		states[image]
	}
	
	/// gets an image's current state and starts a download task if appropriate
	func image(for image: AssetImage?) -> Image? {
		// TODO: does this know to link up to objectWillChange?
		guard let image else { return nil }
		switch state(for: image) {
		case .available, .downloading:
			break
		case nil, .errored:
			Task { await download(image) }
		}
		return cachedImage(for: image)
	}
	
	/// gets an image from cache or loads it. not guaranteed to be up-to-date, but it doesn't take a web request.
	func cachedImage(for image: AssetImage) -> Image? {
		if let cached = cached[image] {
			return cached
		} else  {
			return Image(at: image.localURL) <- { cached[image] = $0 }
		}
	}
	
	func download(_ image: AssetImage) async {
		switch states[image] {
		case nil, .errored:
			break
		case .downloading, .available:
			return
		}
		
		guard inProgress.insert(image).inserted else { return }
		defer { inProgress.remove(image) }
		
		if image.hasMetadata {
			do {
				let meta = try image.loadMetadata()
				// already checked against this version
				if meta.lastVersionCheckedAgainst == Self.version {
					states[image] = .available
					return
				}
			} catch {
				print("could not load metadata for \(image): \(error)")
			}
		}
		
		do {
			// TODO: maybe only set to downloading if not finished within x time?
			states[image] = .downloading
			let wasReplaced = try await client.ensureDownloaded(image)
			if wasReplaced {
				cached[image] = nil
			}
			states[image] = .available
		} catch {
			print("error loading image from \(image.url) stored at \(image.localURL):")
			dump(error)
			states[image] = .errored(error)
			return
		}
		
		var meta = (try? image.loadMetadata()) ?? .init(
			versionDownloaded: Self.version,
			lastVersionCheckedAgainst: Self.version
		)
		meta.lastVersionCheckedAgainst = Self.version
		do {
			try image.save(meta)
		} catch {
			print("could not save metadata for \(image): \(error)")
		}
	}
	
	private func view(for image: AssetImage) throws -> Image {
		try Image(at: image.localURL) ??? ImageLoadingError.loadFromFileFailed
	}
	
	func clear() {
		states = [:]
		cached = [:]
		try? AssetImage.removeCachedFiles()
		// if any loads are in progress, they might still set the state right after this, but i've decided i don't care
	}
	
	enum ImageState {
		case downloading
		case errored(Error)
		case available
	}
	
	enum ImageLoadingError: Error {
		case loadFromFileFailed
	}
}

private struct ImageMetadata: Codable {
	var versionDownloaded: String
	var lastVersionCheckedAgainst: String
}

private extension AssetImage {
	var metadataURL: URL {
		localURL.deletingPathExtension().appendingPathExtension("json")
	}
	
	var hasMetadata: Bool {
		FileManager.default.fileExists(atPath: metadataURL.path)
	}
	
	func loadMetadata() throws -> ImageMetadata {
		try JSONDecoder().decode(ImageMetadata.self, from: Data(contentsOf: metadataURL))
	}
	
	func save(_ metadata: ImageMetadata) throws {
		try JSONEncoder().encode(metadata).write(to: metadataURL)
	}
}
