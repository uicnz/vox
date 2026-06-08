import Foundation

public enum TranscriptionModelFamily: String, Codable, CaseIterable, Sendable {
	case whisperKit
	case parakeet
	case nemotron

	public var usesFluidAudio: Bool {
		switch self {
		case .parakeet, .nemotron:
			return true
		case .whisperKit:
			return false
		}
	}
}

public enum TranscriptionModelCatalog {
	public static func family(for identifier: String) -> TranscriptionModelFamily {
		if ParakeetModel(rawValue: identifier) != nil {
			return .parakeet
		}
		if NemotronModel(rawValue: identifier) != nil {
			return .nemotron
		}
		return .whisperKit
	}

	public static func usesFluidAudio(_ identifier: String) -> Bool {
		family(for: identifier).usesFluidAudio
	}

	public static var fluidAudioModelIdentifiers: [String] {
		ParakeetModel.allCases.map(\.identifier) + NemotronModel.allCases.map(\.identifier)
	}
}
