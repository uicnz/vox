//
//  SoundEffect.swift
//  Vox
//


import AVFoundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation
import VoxCore
import SwiftUI

// Thank you. Never mind then.What a beautiful idea.
public enum SoundEffect: String, CaseIterable {
  case pasteTranscript
  case startRecording
  case stopRecording
  case cancel

  public var fileName: String {
    self.rawValue
  }

  var fileExtension: String {
    "mp3"
  }
}

@DependencyClient
public struct SoundEffectsClient {
  public var play: @Sendable (SoundEffect) -> Void
  public var stop: @Sendable (SoundEffect) -> Void
  public var stopAll: @Sendable () -> Void
  public var preloadSounds: @Sendable () async -> Void
  public var setEnabled: @Sendable (Bool) async -> Void
}

extension SoundEffectsClient: DependencyKey {
  public static var liveValue: SoundEffectsClient {
    let live = SoundEffectsClientLive()
    return SoundEffectsClient(
      play: { soundEffect in
        Task { await live.play(soundEffect) }
      },
      stop: { soundEffect in
        Task { await live.stop(soundEffect) }
      },
      stopAll: {
        Task { await live.stopAll() }
      },
      preloadSounds: {
        await live.preloadSounds()
      },
      setEnabled: { enabled in
        await live.setEnabled(enabled)
      }
    )
  }
}

public extension DependencyValues {
  var soundEffects: SoundEffectsClient {
    get { self[SoundEffectsClient.self] }
    set { self[SoundEffectsClient.self] = newValue }
  }
}

private final class SoundEffectPlayback {
  let engine = AVAudioEngine()
  var playerNodes: [SoundEffect: AVAudioPlayerNode] = [:]
  var audioBuffers: [SoundEffect: AVAudioPCMBuffer] = [:]
  var isEngineRunning = false

  deinit {
    playerNodes.values.forEach {
      $0.stop()
      engine.detach($0)
    }
    engine.stop()
  }
}

actor SoundEffectsClientLive {
  private let logger = VoxLog.sound
  private let baselineVolume = VoxSettings.baseSoundEffectsVolume

  private let playback = SoundEffectPlayback()
  @Shared(.voxSettings) var voxSettings: VoxSettings

  func play(_ soundEffect: SoundEffect) {
    guard voxSettings.soundEffectsEnabled else { return }
    guard let player = playback.playerNodes[soundEffect], let buffer = playback.audioBuffers[soundEffect] else {
      logger.error("Requested sound \(soundEffect.rawValue) not preloaded")
      return
    }
    prepareEngineIfNeeded()
    let clampedVolume = min(max(voxSettings.soundEffectsVolume, 0), baselineVolume)
    player.volume = Float(clampedVolume)
    player.stop()
    player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    player.play()
  }

  func stop(_ soundEffect: SoundEffect) {
    playback.playerNodes[soundEffect]?.stop()
  }

  func stopAll() {
    playback.playerNodes.values.forEach { $0.stop() }
  }

  func preloadSounds() async {
    guard !isSetup else { return }

    for soundEffect in SoundEffect.allCases {
      loadSound(soundEffect)
    }

    isSetup = true
  }

  func setEnabled(_: Bool) async {
    await preloadSounds()

    if voxSettings.soundEffectsEnabled {
      prepareEngineIfNeeded()
    } else {
      stopAll()
      stopEngineIfNeeded()
    }
  }

  private var isSetup = false

  private func loadSound(_ soundEffect: SoundEffect) {
    guard let url = Bundle.main.url(
      forResource: soundEffect.fileName,
      withExtension: soundEffect.fileExtension
    ) else {
      logger.error("Missing sound resource \(soundEffect.fileName).\(soundEffect.fileExtension)")
      return
    }

    do {
      let file = try AVAudioFile(forReading: url)
      let frameCount = AVAudioFrameCount(file.length)
      guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
        logger.error("Failed to allocate buffer for \(soundEffect.rawValue)")
        return
      }
      try file.read(into: buffer)
      playback.audioBuffers[soundEffect] = buffer

      let player = AVAudioPlayerNode()
      playback.engine.attach(player)
      playback.engine.connect(player, to: playback.engine.mainMixerNode, format: buffer.format)
      playback.playerNodes[soundEffect] = player
    } catch {
      logger.error("Failed to load sound \(soundEffect.rawValue): \(error.localizedDescription)")
    }
  }

  private func prepareEngineIfNeeded() {
    if !playback.isEngineRunning || !playback.engine.isRunning {
      playback.engine.prepare()
      if #available(macOS 13.0, *) {
        playback.engine.isAutoShutdownEnabled = false
      }
      do {
        try playback.engine.start()
        playback.isEngineRunning = true
      } catch {
        logger.error("Failed to start AVAudioEngine: \(error.localizedDescription)")
      }
    }
  }

  private func stopEngineIfNeeded() {
    guard playback.isEngineRunning || playback.engine.isRunning else { return }
    playback.engine.stop()
    playback.isEngineRunning = false
  }
}
