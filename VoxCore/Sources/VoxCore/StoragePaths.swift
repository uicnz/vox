import Foundation

public extension URL {
	static var voxApplicationSupport: URL {
		get throws {
			let fm = FileManager.default
			let appSupport = try fm.url(
				for: .applicationSupportDirectory,
				in: .userDomainMask,
				appropriateFor: nil,
				create: true
			)
			let voxDirectory = appSupport.appendingPathComponent("nz.uic.vox", isDirectory: true)
			try fm.createDirectory(at: voxDirectory, withIntermediateDirectories: true)
			return voxDirectory
		}
	}

	static var legacyDocumentsDirectory: URL {
		FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	}

	static func voxMigratedFileURL(named fileName: String) -> URL {
		let newURL = (try? voxApplicationSupport.appending(component: fileName))
			?? documentsDirectory.appending(component: fileName)
		let legacyURL = legacyDocumentsDirectory.appending(component: fileName)
		FileManager.default.migrateIfNeeded(from: legacyURL, to: newURL)
		return newURL
	}

	static var voxModelsDirectory: URL {
		get throws {
			let modelsDirectory = try voxApplicationSupport.appendingPathComponent("models", isDirectory: true)
			try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
			return modelsDirectory
		}
	}

	/// Where FluidAudio-backed ASR models keep their on-disk model caches.
	///
	/// FluidAudio writes to `<Application Support>/FluidAudio/Models/<variant>` in
	/// the sandboxed container. We surface that location so "Show in Finder"
	/// can reveal Parakeet/Nemotron caches instead of the WhisperKit-only models
	/// directory.
	static var voxFluidAudioModelsDirectory: URL {
		get throws {
			let fm = FileManager.default
			let appSupport = try fm.url(
				for: .applicationSupportDirectory,
				in: .userDomainMask,
				appropriateFor: nil,
				create: true
			)
			let dir = appSupport.appendingPathComponent("FluidAudio/Models", isDirectory: true)
			try fm.createDirectory(at: dir, withIntermediateDirectories: true)
			return dir
		}
	}

	static var voxParakeetModelsDirectory: URL {
		get throws {
			try voxFluidAudioModelsDirectory
		}
	}
}

public extension FileManager {
	func migrateIfNeeded(from legacy: URL, to new: URL) {
		guard fileExists(atPath: legacy.path), !fileExists(atPath: new.path) else { return }
		try? copyItem(at: legacy, to: new)
	}

	func removeItemIfExists(at url: URL) {
		guard fileExists(atPath: url.path) else { return }
		try? removeItem(at: url)
	}
}
