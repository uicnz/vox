# Vox HotKey Semantics

## Purpose

This document describes how Vox interprets hotkey input in
`HotKeyProcessor`, and how those processor outputs become recording,
discard, cancel, or transcription behavior in `TranscriptionFeature`.

The important split is between modifier-only hotkeys, such as `Option`,
and key-plus-modifier hotkeys, such as `Command+A`.

## Timing Constants

- `modifierOnlyMinimumDuration`: `0.3s` safety floor for modifier-only
  hotkeys.
- `minimumKeyTime`: `0.2s` default user setting; can be higher or lower.
- `doubleTapThreshold`: `0.3s` maximum gap between tap releases for lock
  mode.
- `pressAndHoldCancelThreshold`: `1.0s` early interruption window for
  key-plus-modifier hotkeys.

Modifier-only hotkeys use an effective minimum duration:

```swift
max(minimumKeyTime, modifierOnlyMinimumDuration)
```

With the default settings that is `0.3s`. If the user raises
`minimumKeyTime` to `0.5s`, modifier-only hotkeys use `0.5s`.

## Output Vocabulary

- `.startRecording`: begin capturing microphone audio.
- `.stopRecording`: stop the active recording and let
  `RecordingDecisionEngine` decide whether to transcribe.
- `.cancel`: explicit ESC cancellation; stop and discard with cancel feedback.
- `.discard`: silent accidental-input discard; stop and delete audio.
- `nil`: no app action; keep current state.

`.stopRecording` is not the same as "transcribe no matter what." For
modifier-only hotkeys, `RecordingDecisionEngine` discards recordings shorter
than the effective modifier-only minimum. For key-plus-modifier hotkeys, a
normal release proceeds to transcription.

## Modifier-Only Hotkeys

### Modifier-Only Activation

A modifier-only hotkey matches only when all configured modifiers are held and
no key is pressed. For example, `Option` starts recording on:

```text
key: nil
modifiers: [.option]
```

It does not start when the modifier is already being used with another key,
for example `Option+A`.

### Modifier-Only Early Input

Before the effective modifier-only minimum duration, non-ESC interruptions are
treated as accidental input:

| Input before effective minimum | User-visible behavior |
| --- | --- |
| Release hotkey | Silent discard after stop decision |
| Press another key | `.discard`, silent |
| Add an extra modifier | `.discard`, silent |
| Mouse click | `.discard`, silent |
| Press ESC | `.cancel` |

Discarded keyboard events pass through to macOS. This preserves OS and app
shortcuts such as `Option+A`, `Option+Click`, and `Command+Click`.

### Modifier-Only Established Recording

Once the recording has reached the effective modifier-only minimum, Vox treats
the hotkey as intentional:

| Input after effective minimum | User-visible behavior |
| --- | --- |
| Release hotkey | Stop and transcribe |
| Press another key | Ignore and keep recording |
| Add an extra modifier | Ignore and keep recording |
| Mouse click | Ignore and keep recording |
| Press ESC | `.cancel` |

After the threshold, only releasing the hotkey or pressing ESC ends the
recording.

### Modifier-Only Release Decision

For a normal release, the processor emits `.stopRecording`. The transcription
feature then applies this duration check:

```swift
duration >= max(minimumKeyTime, modifierOnlyMinimumDuration)
```

If the duration is shorter, Vox silently discards the recording. If the
duration is long enough, Vox stops recording, plays stop feedback, and
transcribes the captured audio.

### Modifier-Only Multi-Modifier Hotkeys

Multi-modifier hotkeys, such as `Option+Command`, use the same rules as a
single modifier-only hotkey. The release of any required modifier counts as
the hotkey release.

```text
Hold Option+Command -> release Command while keeping Option -> stop
```

Adding an extra modifier after the effective minimum is ignored. Adding an
extra modifier before the effective minimum silently discards and marks input
dirty until every key and modifier is released.

## Key-Plus-Modifier Hotkeys

### Key-Plus-Modifier Activation

A key-plus-modifier hotkey matches only when the key and modifier set match
exactly. For example, `Command+A` starts recording on:

```text
key: .a
modifiers: [.command]
```

The initial matching key event is intercepted so the target app does not also
handle the configured hotkey.

### Key-Plus-Modifier Release Decision

For key-plus-modifier hotkeys, releasing the key is the normal stop signal.
Modifiers may still be held when the key is released.

```text
Hold Command+A -> release A while keeping Command -> stop
```

Normal key-plus-modifier release emits `.stopRecording` and proceeds to
transcription. The current `RecordingDecisionEngine` does not discard normal
key-plus-modifier releases based on `minimumKeyTime`.

### Key-Plus-Modifier Other Input

If the user changes the chord while recording, timing decides the outcome:

| Input timing | User-visible behavior |
| --- | --- |
| Before `minimumKeyTime` | `.discard`, silent |
| From `minimumKeyTime` through `1.0s` | `.stopRecording` |
| After `1.0s` | Ignore and keep recording |

Mouse clicks are ignored for key-plus-modifier hotkeys because there is no
modifier-only mouse shortcut conflict to protect.

## Double-Tap Lock

Double-tap lock lets a user enter hands-free recording. It is enabled by
default unless `doubleTapLockEnabled` is false.

### Double-Tap Lock Sequence

```text
0.0s: press hotkey     -> .startRecording
0.1s: release hotkey   -> .stopRecording
0.2s: press hotkey     -> .startRecording
0.3s: release hotkey   -> lock remains recording, output nil
```

The lock engages on the second release, not the second press. The second
release must occur within `doubleTapThreshold` of the previous release.

If the second tap is held too long, Vox treats it as an ordinary press-and-hold
recording and stops on release.

### Double-Tap Lock Exit

While locked, Vox keeps recording until one of these events occurs:

| Exit input | Output |
| --- | --- |
| Press matching hotkey again | `.stopRecording` |
| Press ESC | `.cancel` |

Other input is ignored while the locked recording continues.

### Double-Tap Only Mode

`useDoubleTapOnly` applies only to key-plus-modifier hotkeys and only when
double-tap lock is enabled. Modifier-only hotkeys always support
press-and-hold because they are the primary low-friction recording path.

## Dirty State

Dirty state prevents "backsliding" into a hotkey after unrelated key input.
When dirty, Vox ignores all input until a full keyboard release occurs.

### Dirty State Triggers

Dirty state is entered after accidental or unrelated input, including:

- Extra modifiers before a modifier-only recording reaches its effective minimum
- Any key press before a modifier-only recording reaches its effective minimum
- Different keys or extra modifiers during the key-plus-modifier early window
- ESC cancellation while the hotkey is still physically held
- Pressing a chord that contains extra keys or modifiers before the hotkey ever
  matched

### Dirty State Clearing

Dirty state clears only when the keyboard is fully released:

```text
key: nil
modifiers: []
```

This prevents a sequence like `Option+Shift -> release Shift` from activating
an `Option` hotkey without a fresh standalone `Option` press.

## Event Interception

| Event | Intercepted from target app |
| --- | --- |
| Modifier-only hotkey press | No |
| Key-plus-modifier hotkey press | Yes |
| `.discard` output | No |
| `.cancel` output | Yes |
| Mouse click | No |

Modifier-only hotkeys pass through so macOS shortcuts keep working. Key-plus-
modifier hotkeys are blocked on the matching press because they are explicit
Vox commands.

## Operational Examples

### Example: Option Character

```text
Goal: type a special character with Option+A

0.00s: press Option -> .startRecording
0.15s: press A      -> .discard

Result: Vox silently discards. macOS receives Option+A.
```

### Example: Intentional Option Recording

```text
Goal: record a voice note with Option

0.00s: press Option   -> .startRecording
0.50s: keep holding   -> recording continues
2.00s: release Option -> .stopRecording, then transcribe
```

### Example: Typing During Recording

```text
Goal: keep dictating while using other shortcuts

0.00s: press Option       -> .startRecording
0.50s: threshold passed   -> intentional recording
2.00s: press Command+Tab  -> ignored by Vox, passed to macOS
5.00s: release Option     -> .stopRecording, then transcribe
```

### Example: Key-Plus-Modifier Interruption

```text
Goal: Command+A hotkey, user quickly switches to Command+B

0.00s: press Command+A -> .startRecording
0.50s: press Command+B -> .stopRecording

Result: Vox stops because the chord changed inside the 1.0s early window.
```

## Implementation Pointers

- `VoxCore/Sources/VoxCore/Logic/HotKeyProcessor.swift`
- `VoxCore/Sources/VoxCore/Logic/RecordingDecision.swift`
- `Vox/Features/Transcription/TranscriptionFeature.swift`
- `VoxCore/Tests/VoxCoreTests/HotKeyProcessorTests.swift`
