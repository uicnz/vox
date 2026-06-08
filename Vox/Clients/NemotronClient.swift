import AVFoundation
import Foundation
import VoxCore

#if canImport(FluidAudio)
import FluidAudio

actor NemotronClient {
  private var manager: StreamingNemotronMultilingualAsrManager?
  private var currentModel: NemotronModel?
  private let logger = VoxLog.nemotron

  func isModelAvailable(_ modelName: String) async -> Bool {
    guard let model = NemotronModel(rawValue: modelName) else {
      logger.error("Unknown Nemotron variant requested: \(modelName)")
      return false
    }
    if currentModel == model, manager != nil { return true }

    logger.debug("Checking Nemotron availability model=\(model.identifier)")
    for dir in modelDirectories(model) {
      if directoryContainsNemotronBundle(dir) {
        logger.notice("Found Nemotron cache at \(dir.path)")
        return true
      }
    }
    logger.debug("No Nemotron cache detected model=\(model.identifier)")
    return false
  }

  func ensureLoaded(modelName: String, progress: @escaping (Progress) -> Void) async throws {
    guard let model = NemotronModel(rawValue: modelName) else {
      throw NSError(
        domain: "Nemotron",
        code: -4,
        userInfo: [NSLocalizedDescriptionKey: "Unsupported Nemotron variant: \(modelName)"]
      )
    }

    if currentModel == model, manager != nil { return }
    if currentModel != model {
      manager = nil
    }

    let t0 = Date()
    logger.notice("Starting Nemotron load model=\(model.identifier)")

    let p = Progress(totalUnitCount: 100)
    p.completedUnitCount = 1
    progress(p)

    let cacheRoot = try URL.voxFluidAudioModelsDirectory
    let variantDir = try await StreamingNemotronMultilingualAsrManager.downloadVariant(
      languageCode: model.languageCode,
      chunkMs: model.chunkMilliseconds,
      to: cacheRoot,
      progressHandler: { downloadProgress in
        p.completedUnitCount = Int64(5 + min(max(downloadProgress.fractionCompleted, 0), 1) * 80)
        progress(p)
      }
    )

    p.completedUnitCount = max(p.completedUnitCount, 90)
    progress(p)

    let nextManager = StreamingNemotronMultilingualAsrManager()
    try await nextManager.loadModels(from: variantDir)
    await nextManager.setLanguage(model.languageCode)
    self.manager = nextManager
    self.currentModel = model

    p.completedUnitCount = 100
    progress(p)
    logger.notice("Nemotron ensureLoaded completed in \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
  }

  func transcribe(_ url: URL) async throws -> String {
    guard let manager else {
      throw NSError(
        domain: "Nemotron",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Nemotron not initialized"]
      )
    }

    let t0 = Date()
    logger.notice("Transcribing with Nemotron file=\(url.lastPathComponent)")

    let audioFile = try AVAudioFile(forReading: url)
    let inputFormat = audioFile.processingFormat
    let audioDuration = Double(audioFile.length) / inputFormat.sampleRate
    let blockFrames = AVAudioFrameCount(inputFormat.sampleRate * 60)
    let converter = AudioConverter()

    while audioFile.framePosition < audioFile.length {
      let remaining = AVAudioFrameCount(audioFile.length - audioFile.framePosition)
      let framesToRead = min(blockFrames, remaining)
      guard let block = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: framesToRead) else {
        throw NSError(
          domain: "Nemotron",
          code: -5,
          userInfo: [NSLocalizedDescriptionKey: "Unable to allocate audio buffer for Nemotron transcription"]
        )
      }
      try audioFile.read(into: block, frameCount: framesToRead)
      guard block.frameLength > 0 else { break }

      let samples = try converter.resampleBuffer(block)
      if !samples.isEmpty {
        _ = try await manager.process(samples: samples)
      }
    }

    let text = try await manager.finish()
    let detectedLanguage = await manager.detectedLanguage() ?? "unknown"
    await manager.reset()

    logger.info(
      "Nemotron transcription finished in \(String(format: "%.2f", Date().timeIntervalSince(t0)))s duration=\(String(format: "%.2f", audioDuration))s detected=\(detectedLanguage)"
    )
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func deleteCaches(modelName: String) async throws {
    guard let model = NemotronModel(rawValue: modelName) else { return }
    let fm = FileManager.default

    var removedAny = false
    for dir in modelDirectories(model) {
      if fm.fileExists(atPath: dir.path) {
        try? fm.removeItem(at: dir)
        removedAny = true
      }
    }

    if removedAny || currentModel == model {
      manager = nil
      if currentModel == model {
        currentModel = nil
      }
    }
  }

  func unload() {
    manager = nil
    currentModel = nil
  }

  private func modelDirectories(_ model: NemotronModel) -> [URL] {
    candidateRoots().map {
      $0.appendingPathComponent(model.cacheRelativePath, isDirectory: true)
    }
  }

  private func candidateRoots() -> [URL] {
    let fm = FileManager.default
    let appSupport = try? fm.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: false
    )
    let fluidAudio = try? URL.voxFluidAudioModelsDirectory
    let appCache = try? URL.voxApplicationSupport.appendingPathComponent("cache/FluidAudio/Models", isDirectory: true)
    let xdgFluidAudio = ProcessInfo.processInfo.environment["XDG_CACHE_HOME"]
      .map { URL(fileURLWithPath: $0, isDirectory: true).appendingPathComponent("FluidAudio/Models", isDirectory: true) }
    let appSupportFluidAudio = appSupport?.appendingPathComponent("FluidAudio/Models", isDirectory: true)
    return [fluidAudio, appSupportFluidAudio, appCache, xdgFluidAudio].compactMap { $0 }
  }

  private func directoryContainsNemotronBundle(_ dir: URL) -> Bool {
    let fm = FileManager.default
    guard fm.fileExists(atPath: dir.appendingPathComponent("metadata.json").path) else {
      return false
    }
    guard let en = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else {
      return false
    }
    for case let url as URL in en {
      if url.pathExtension == "mlmodelc" || url.lastPathComponent.hasSuffix(".mlmodelc") {
        return true
      }
    }
    return false
  }
}

#else

actor NemotronClient {
  func isModelAvailable(_ modelName: String) async -> Bool { false }
  func ensureLoaded(modelName: String, progress: @escaping (Progress) -> Void) async throws {
    throw NSError(
      domain: "Nemotron",
      code: -2,
      userInfo: [NSLocalizedDescriptionKey: "Nemotron support not linked. Add Swift Package: https://github.com/FluidInference/FluidAudio.git and link FluidAudio to Vox."]
    )
  }
  func transcribe(_ url: URL) async throws -> String {
    throw NSError(
      domain: "Nemotron",
      code: -3,
      userInfo: [NSLocalizedDescriptionKey: "Nemotron not available"]
    )
  }
  func unload() {}
  func deleteCaches(modelName: String) async throws {}
}

#endif
