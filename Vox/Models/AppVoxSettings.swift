import ComposableArchitecture
import Dependencies
import Foundation
import VoxCore

// Re-export types so the app target can use them without VoxCore prefixes.
typealias RecordingAudioBehavior = VoxCore.RecordingAudioBehavior
typealias VoxSettings = VoxCore.VoxSettings

extension SharedReaderKey
	where Self == FileStorageKey<VoxSettings>.Default
{
	static var voxSettings: Self {
		Self[
			.fileStorage(.voxSettingsURL),
			default: .init()
		]
	}
}

// MARK: - Storage Migration

extension URL {
	static var voxSettingsURL: URL {
		get {
			URL.voxMigratedFileURL(named: "vox_settings.json")
		}
	}
}
