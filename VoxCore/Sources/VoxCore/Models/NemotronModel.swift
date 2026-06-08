import Foundation

/// Known NVIDIA Nemotron Core ML bundles that Vox supports.
public enum NemotronModel: String, CaseIterable, Sendable {
	case multilingualFull2240 = "nemotron-3.5-asr-streaming-0.6b-multilingual-coreml-2240ms"

	/// The identifier used throughout the app.
	public var identifier: String { rawValue }

	/// FluidAudio language selector. `auto` routes to the full-vocabulary
	/// `multilingual/` model instead of the pruned Latin-script bundle.
	public var languageCode: String { "auto" }

	/// FluidAudio chunk-size tier. 2240 ms is the upstream recommended balance.
	public var chunkMilliseconds: Int { 2240 }

	/// Path below FluidAudio's model cache root.
	public var cacheRelativePath: String {
		"nemotron-multilingual/multilingual/\(chunkMilliseconds)ms"
	}

	public var capabilityLabel: String { "Full multilingual" }
	public var recommendationLabel: String { "Nemotron 3.5" }
}
