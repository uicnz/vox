import Testing
@testable import VoxCore

struct TranscriptionModelFamilyTests {
	@Test
	func classifiesKnownModelFamilies() {
		#expect(TranscriptionModelCatalog.family(for: ParakeetModel.englishV2.identifier) == .parakeet)
		#expect(TranscriptionModelCatalog.family(for: ParakeetModel.multilingualV3.identifier) == .parakeet)
		#expect(TranscriptionModelCatalog.family(for: NemotronModel.multilingualFull2240.identifier) == .nemotron)
		#expect(TranscriptionModelCatalog.family(for: "openai_whisper-base") == .whisperKit)
	}

	@Test
	func identifiesFluidAudioModels() {
		#expect(TranscriptionModelCatalog.usesFluidAudio(ParakeetModel.multilingualV3.identifier))
		#expect(TranscriptionModelCatalog.usesFluidAudio(NemotronModel.multilingualFull2240.identifier))
		#expect(!TranscriptionModelCatalog.usesFluidAudio("openai_whisper-base"))
	}
}
