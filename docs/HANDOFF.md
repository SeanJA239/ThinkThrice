# ThinkThrice handoff

ThinkThrice (planning name 冷静期) is the iOS app for the CPX hackathon, Track 2 (reverse UX). Sean owns the app; Ryan (睿洋) owns the model. The plan this code follows is in the planning thread <https://ampcode.com/threads/T-01a1fbc2-a317-7698-87df-0c16c2ac87ef> and the tech split <https://ampcode.com/artifacts/a110c9ee-a56c-4ae5-901d-5773c7e87fc9>.

## Status

Everything in the plan up to M2 works, plus most of M3. It was built and run on a cloud Mac (Xcode 27.3, iOS 27.3 simulator, iPhone 17 Pro). It has not been run on a real iPhone yet.

| Milestone | State |
|---|---|
| M0 project, ExyteChat, scripted replies | Done (simulator) |
| M1 CalmCore reducer, TimePolicy, DemoClock, tests, scoring on send, settling bubble | Done |
| M2 action panel, ritual, confirm, dissolve, `ready`, demo clock panel | Done |
| M3 melt editor + rescoring | Done |
| M3 local notification | Written, not checked on a device |
| M3 SwiftData persistence | Not started (first in the cut list) |
| M3 Core ML scorer with model v1 | Code and contract test done; waiting for Ryan's model |
| M4 Liquid Glass polish, animations, accessibility | Partly: glass contact header, frozen Liquid Glass shell around held messages, iMessage-style time headers and 「已送达」, input bar, bubbles and sheets, in-bubble glass-to-solid transition on delivery, VoiceOver labels on held bubbles, Reduce Motion on dissolve |
| Two-device demo (optional, after M3) | Only the transport protocol exists; see "Two devices" |

How it was checked:

- `cd CalmCore && swift test`: 41 tests in 12 suites pass on macOS. They cover the threshold boundaries, crossing midnight, rewrites that drop below or stay above the threshold, an abandoned ritual, the demo clock, the keyword scorer and the Core ML contract.
- `xcodebuild` for the iOS simulator succeeds with no warnings in app or CalmCore code.
- A scratch XCUITest (kept out of the repo) drove the whole flow in the simulator: a calm message delivered with a scripted reply, a day settle, the action panel, cancelling the melt editor, the day ritual (one page, button locked for 5 s), jumping the demo clock to 1:30, a night settle, the three-page night ritual abandoned with 「算了」, fast-forwarding to 9:00, `ready`, confirm and send, a rewrite that calms down and is delivered with a banner, and letting go with the dissolve. It passed.

## Structure

```
ThinkThrice/
├─ project.yml               XcodeGen spec (source of truth for the project)
├─ ThinkThrice.xcodeproj     generated from project.yml and committed
├─ CalmCore/                 Swift package, no UI; runs with `swift test`
│  ├─ Sources/CalmCore/
│  │  ├─ SettleState.swift     SettleState enum + CalmMessage record
│  │  ├─ Reducer.swift         SettleEvent + reduce(message, event, now:, policy:)
│  │  ├─ TimePolicy.swift      thresholds, night window, settle durations, question counts, timings
│  │  ├─ Scorer.swift          Scorer protocol, FixedScorer, MaxScorer, KeywordScorer, NLTaggerScorer, CoreMLScorer
│  │  ├─ Clock.swift           CalmClock protocol, SystemClock, DemoClock
│  │  ├─ Sentences.swift       rule-based splitter for the melt editor
│  │  └─ MessageTransport.swift  MessageTransport protocol, WireMessage, ScriptedTransport
│  └─ Tests/CalmCoreTests/   unit tests + Fixtures/TinyImpulse.mlmodel (toy model for the contract test)
└─ App/
   ├─ ThinkThriceApp.swift, AppModel.swift   app services: demo clock, policy, scorer, content, stores
   ├─ ChatStore.swift          one conversation: records by message id, side effects, sheet routing
   ├─ ChatScreen.swift         exyte ChatView, messageBuilder, inputViewBuilder, sheets, banner, ChatHeader
   ├─ ConversationListView.swift, InputBar.swift, Content.swift, Notifications.swift, DebugClockPanel.swift
   ├─ Bubbles/HeldBubbles.swift   CalmMessageCell, DeliveredBubble, SettlingBubble, ReadyBubble, DissolveBubble
   ├─ Sheets/                  ActionPanel, RitualSheet, ConfirmSheet, MeltEditor
   ├─ Resources/Questions.json, Scripts.json   copy the non-tech teammates edit
   └─ Model/                   drop the model here (see below)
```

How a message moves: exyte calls `didSendMessage` → `ChatStore.submit` adds a `CalmMessage` in `.scoring` → the scorer runs off the main actor → `reduce(.scored)` → delivered (sent through `MessageTransport`, which triggers the scripted reply) or settling (notification scheduled). exyte's `Message` is display-only; `messageBuilder` looks up `records[message.id]`: every outgoing message has a record and is drawn with our own bubbles (solid `DeliveredBubble` in exyte's theme colours once delivered; while held, the muted bubble sits frozen inside a thick `.clear` Liquid Glass shell with a bright rim, and the countdown sits under it); messages from the other side use exyte's default bubble. Times are never drawn inside bubbles: as in iMessage, a centered header (「9:00」, 「昨天 1:30」) starts each run of messages more than 10 minutes after the previous one (`ChatStore.timeHeader(for:)`), and only the newest delivered message shows 「已送达」 under it. A held message's header uses the time it was written; once delivered it uses the delivery time. Every state change bumps `Message.triggerRedraw` so the table row redraws.

State machine as implemented (`SettleState`): `scoring → delivered | settling`; `settling → ready` on tick once `settleUntil` passes; `settling/ready → ritual(step, total) → delivered` (or back on 「算了」); `ready → confirming → delivered` (or back to `ready`); `settling/ready → rewriting(revealed) → rescoring → delivered | settling/ready`; any held state `→ dissolving → dissolved`. `settleUntil` is set once and never reset, so ritual, confirm and rewrite branches all return to the same countdown. Events that don't apply leave the message unchanged.

## Build and test

On a Mac with Xcode 26 or later (the demo iPhone needs iOS 26 or later):

1. `open ThinkThrice.xcodeproj`, pick your team under Signing & Capabilities (`DEVELOPMENT_TEAM` is empty and the bundle ID is `com.thinkthrice.app`; change it if it's taken), and run on the iPhone. The first build is slow because ExyteChat pulls in Kingfisher, Giphy and MediaPicker.
2. `cd CalmCore && swift test` runs the core tests. They also run from Xcode if you add the package's test target to the scheme.
3. After editing `project.yml` or adding or removing files under `App/`, run `xcodegen generate` (`brew install xcodegen`) and commit the regenerated project. Adding a file only through Xcode also works, but then `project.yml` is out of date.

The chat's contact header is a Liquid Glass capsule with the avatar initial, an online dot, the name and a status line: 「在线」, or 「正在输入…」 while a scripted reply is on its way (`ChatStore.peerIsTyping`). The scripted peers are always online; a P2P transport would need to report presence and typing itself.

Demo controls: in a chat, triple-tap the contact header to open the demo panel. It can jump to 01:30, fast-forward to 09:00 or by 15 minutes, return to real time, adjust the night and day thresholds with sliders, and score any sentence with the live scorer. While the clock is shifted, the header's status line adds 「演示时间 …」.

All timings and thresholds live in `CalmCore/Sources/CalmCore/TimePolicy.swift`: night 23:00–6:00, threshold 0.5 at night and 0.7 by day (a score ≥ threshold settles), night settles until 9:00, day settles 15 minutes, 3 ritual pages at night and 1 by day, 5 s per ritual page, 1.5 s per melt-editor piece.

## Model contract (for Ryan)

- Create ML Text Classifier with exactly two labels, `impulsive` and `calm`. Export a `.mlmodel`.
- Name it `ImpulseClassifier.mlmodel` and put it in `App/Model/`. Then run `xcodegen generate` (or drag it into the ThinkThrice target in Xcode) so it's in the app target; Xcode compiles it into the bundle.
- The app loads it with `NLModel` and uses `predictedLabelHypotheses(for:maximumCount:)["impulsive"]` as the 0–1 score (`CoreMLScorer`). If the file isn't in the bundle, the app falls back to the keyword scorer. The demo panel shows which scorer is live (「Core ML（ImpulseClassifier）」 or 「关键词兜底（未找到模型）」), and its probe field shows the score for any sentence.
- Thresholds from the evaluation report go into `TimePolicy` (`nightThreshold`, `dayThreshold`). They can also be tried on site with the sliders, but slider changes are not saved.
- If the model ends up being a converted RoBERTa instead of Create ML, `CoreMLScorer` won't load it: that path needs tokenisation in the app and a new `Scorer` implementation. Talk to Sean first, as the plan says.
- `CalmCore/Tests/CalmCoreTests/Fixtures/TinyImpulse.mlmodel` is a 30-sentence toy model used only to test the contract. Don't ship it.

Workaround to know about: the plan's fallback was `NLTagger` sentiment, but on macOS 27 `NLTagger` has no sentiment scheme for Simplified Chinese and tags every Chinese sentence `Other` (English works). So the fallback is `KeywordScorer`, a small weighted lexicon of impulsive phrases combined with noisy-OR, joined with `NLTaggerScorer` through `MaxScorer`. Sadness words are deliberately not in the lexicon. It's good enough for the demo sentences but is not a model. Check on the demo iPhone whether iOS behaves the same; it probably does.

## Two devices (optional, after M3, not decided)

Not MultipeerConnectivity (deprecated; TN3151, TN3213). The plan is Network.framework:

- `MessageTransport` (in CalmCore) is the seam. `ScriptedTransport` is the only implementation now. Add a `P2PTransport` in the app built on iOS 26's `NetworkListener` / `NetworkBrowser` / `NetworkConnection`: one phone listens and advertises Bonjour `_calmchat._tcp`, the other browses and connects, messages go over `Coder(WireMessage.self, using: .json) { TCP() }`, and `peerToPeerIncluded(true)` so it works over Apple peer-to-peer Wi-Fi without the venue network. Check the browser's Bonjour descriptor against Apple's sample "Building a custom peer-to-peer protocol"; it hasn't been compiled here.
- `WireMessage` is already `Codable`. Only delivered messages are ever passed to `send`, so held text never leaves the device.
- Add `INFOPLIST_KEY_NSLocalNetworkUsageDescription` and `NSBonjourServices` (`_calmchat._tcp`) to the target. `NSBonjourServices` is an array, so it needs an Info.plist file or an `info:` section in `project.yml` rather than an `INFOPLIST_KEY_` setting.
- Add a switch in the demo panel to fall back to the scripted conversation. Today each `ChatStore` creates its `ScriptedTransport` in `init`; make the transport injectable from `AppModel`.
- Test on two real iPhones; the simulator can't do peer-to-peer Wi-Fi. Don't use Wi-Fi Aware.

## Known issues

- Fixed: delivered Chinese messages near one line long used to be cut off with 「…」 in exyte's default bubble (exyte measures text with UIKit, which comes out narrower than SwiftUI's rendering of full-width punctuation, and then applies `lineLimit(1)`). Outgoing messages now use our own `DeliveredBubble`.
- A message delivered after settling stays where it was written, its time header switches to the delivery time, and it turns from glass to solid in place (skipped with Reduce Motion); the scripted reply appears below it.
- Threshold slider changes and all chat state are lost when the app is killed (no persistence yet; SwiftData is first in the cut list).
- Local notifications use a time-interval trigger computed from the demo clock offset (real fire time = `settleUntil` − offset). Moving the clock reschedules them. Check on a device that the 「昨晚 1:47 的那条沉淀好了」 banner appears, including in the foreground.
- Questions and scripted replies are draft copy for the non-tech teammates to replace in `App/Resources/*.json`. When a script runs out, the other side goes quiet.

## Needs a Mac or iPhone to verify

- Real-device run on iOS 26: signing, keyboard avoidance with the custom input bar, Liquid Glass rendering, performance.
- Notification permission prompt and banners on a device.
- Core ML latency and size with Ryan's real model (target: tens of milliseconds).
- Whether `NLTagger` sentiment supports Chinese on iOS (expected: no).

## Next steps

1. Sean: open on a Mac, set the team, run on the demo iPhone, and try the demo panel flow once.
2. Ryan: deliver v0 as `App/Model/ImpulseClassifier.mlmodel` with the two labels; confirm in the demo panel that it shows Core ML and that the demo sentences score as expected.
3. SwiftData persistence of `CalmMessage` records and conversation messages so settling survives a restart (cut first if short on time).
4. M4 polish and accessibility pass; replace draft copy; build the demo sentence list into a rehearsal script.
5. Two-device transport only if Sean confirms, after M3.
