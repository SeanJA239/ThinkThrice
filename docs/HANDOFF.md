# ThinkThrice handoff

ThinkThrice (planning name 冷静期) is the iOS app for the CPX hackathon, Track 2 (reverse UX). Sean owns the app; Ryan (睿洋) owns the model. The plan this code follows is in the planning thread <https://ampcode.com/threads/T-01a1fbc2-a317-7698-87df-0c16c2ac87ef> and the tech split <https://ampcode.com/artifacts/a110c9ee-a56c-4ae5-901d-5773c7e87fc9>.

## Status

Everything in the plan up to M3 works except the real model, plus most of M4 and the optional two-phone mode. It was built and run on a cloud Mac (Xcode 27.3, iOS 27.3 simulator, iPhone 17 Pro). It has not been run on a real iPhone yet, and the two-phone mode has never been tried on two phones.

| Milestone | State |
|---|---|
| M0 project, ExyteChat, scripted replies | Done (simulator) |
| M1 CalmCore reducer, TimePolicy, DemoClock, tests, scoring on send, settling bubble | Done |
| M2 action panel, ritual, confirm, dissolve, `ready`, demo clock panel | Done |
| M3 melt editor + rescoring | Done |
| M3 local notification | Written, not checked on a device |
| M3 persistence | Done as a JSON snapshot per conversation instead of SwiftData (see Persistence) |
| M3 model | Done: Ryan's v2c model plus his keyword rules (see Detector); all 109 of his acceptance sentences pass in `swift test` |
| App shell | Tab bar (聊天 / 三思 / 设置), profile from the chats list's top-left avatar, contact sheet from the chat header, 15-minute cooling pause for both sides |
| M4 Liquid Glass polish, animations, accessibility | Mostly done: snow only while a message is frozen, Watch-style breathing flower on the ritual page, freeze animation with snowflake burst and haptics, day/night sky that follows the demo clock, ice-dust dissolve, thawing melt editor, 「why held」 line in the action panel, countdown ring, richer conversation list, app icon, iMessage-style bubbles with tails, glass contact header, frozen Liquid Glass shell around held messages, 「已送达 9:00」 status line, glass input bar and sheets, in-bubble glass-to-solid transition on delivery, VoiceOver labels on held bubbles, Reduce Motion on dissolve |
| Two-phone demo (optional) | Implemented with Network.framework and compiled for device; never run on two phones (see Two phones) |

How it was checked:

- `cd CalmCore && swift test`: 47 tests in 13 suites pass on macOS. They cover the threshold boundaries, crossing midnight, rewrites that drop below or stay above the threshold, an abandoned ritual, restoring after a relaunch, the demo clock, the keyword scorer and the Core ML contract.
- `xcodebuild` for the iOS simulator and for a generic iOS device succeeds with no warnings in app or CalmCore code.
- A scratch XCUITest (kept out of the repo) drove the whole flow in the simulator: a calm message delivered with a scripted reply, a day settle, the action panel, cancelling the melt editor, the day ritual (one page, button locked for 5 s), jumping the demo clock to 1:30, a night settle, the three-page night ritual abandoned with 「算了」, fast-forwarding to 9:00, `ready`, confirm and send, a rewrite that calms down and is delivered with a banner, and letting go with the dissolve. Between the night settle and the ritual it kills and relaunches the app and checks the settling message and the shifted demo clock are still there. It passed.

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
│  │  ├─ ThinkThriceRules.swift   Ryan's keyword rules and final verdict (add words here)
│  │  ├─ ThinkThriceClassifier.swift  Ryan's model loader and scorer
│  │  ├─ Judge.swift           ThinkThriceJudge (model + rules for a recipient), scene factors
│  │  ├─ ThinkStats.swift      ThinkEvent log and the 三思 progress summary
│  │  ├─ ThinkReview.swift     the 三思 page's headline, closing line and highlights
│  │  ├─ Clock.swift           CalmClock protocol, SystemClock, DemoClock
│  │  ├─ Sentences.swift       rule-based splitter for the melt editor
│  │  └─ MessageTransport.swift  MessageTransport protocol, WireMessage, ScriptedTransport
│  └─ Tests/CalmCoreTests/   unit tests + Fixtures/*.csv (Ryan's acceptance sentences)
└─ App/
   ├─ ThinkThriceApp.swift, AppModel.swift   app services: demo clock, policy, scorer, content, stores
   ├─ ChatStore.swift          one conversation: records by message id, side effects, sheet routing, save/restore
   ├─ Archive.swift            ConversationArchive (JSON per conversation) and DemoSettings (UserDefaults)
   ├─ P2PTransport.swift       two-phone MessageTransport on Network.framework
   ├─ Atmosphere.swift         day/night chat backdrop; snow while a message is frozen
   ├─ Theme.swift              brand violet, avatars
   ├─ StatsStore.swift, StatsView.swift   三思 tab: event log and progress page
   ├─ SettingsView.swift, ProfileView.swift, ContactPanel.swift
   ├─ Model/                   ThinkThriceAnger.mlmodel (main) and ThinkThriceAngerLite.mlmodel (fallback)
   ├─ Haptics.swift            one haptic per settle-flow moment
   ├─ Assets.xcassets          app icon
   ├─ Info.plist               generated by XcodeGen from project.yml: local network and Bonjour keys
   ├─ ChatScreen.swift         exyte ChatView, messageBuilder, inputViewBuilder, sheets, banner, ChatHeader
   ├─ ConversationListView.swift, InputBar.swift, Content.swift, Notifications.swift, DebugClockPanel.swift
   ├─ Bubbles/MessageBubbles.swift   CalmMessageCell, BubbleShape, MessageBubble, DeliveredBubble, SettlingBubble, ReadyBubble, DissolveBubble
   ├─ Sheets/                  ActionPanel, RitualSheet, ConfirmSheet, MeltEditor
   ├─ Resources/Questions.json, Scripts.json   copy the non-tech teammates edit
   └─ Model/                   drop the model here (see below)
```

How a message moves: exyte calls `didSendMessage` → `ChatStore.submit` adds a `CalmMessage` in `.scoring` → the scorer runs off the main actor → `reduce(.scored)` → delivered (sent through `MessageTransport`, which triggers the scripted reply) or settling (notification scheduled). exyte's `Message` is display-only; `messageBuilder` looks up `records[message.id]`: every outgoing message has a record and is drawn with our own bubbles, and so are messages from the other side: iMessage style, consecutive messages from one sender sit 2 pt apart and the last one in each run gets a tail (`BubbleShape`, `ChatStore.groupPosition(of:)`); system blue for mine, system gray for theirs, 17 pt text. While held, the muted bubble sits frozen inside a thick `.clear` Liquid Glass shell with a bright rim and the countdown under it; a held message always stands alone. Times are never drawn inside bubbles: as in iMessage's 「Read 12:54 AM」, only the newest delivered message shows 「**已送达** 9:00」 (delivery time) under it (`ChatStore.lastDeliveredID`), and held messages show their countdown in the same place. Every state change bumps `Message.triggerRedraw` so the table row redraws.

State machine as implemented (`SettleState`): `scoring → delivered | settling`; `settling → ready` on tick once `settleUntil` passes; `settling/ready → ritual(step, total) → delivered` (or back on 「算了」); `ready → confirming → delivered` (or back to `ready`); `settling/ready → rewriting(revealed) → rescoring → delivered | settling/ready`; any held state `→ dissolving → dissolved`. `settleUntil` is set once and never reset, so ritual, confirm and rewrite branches all return to the same countdown. Events that don't apply leave the message unchanged.

## Build and test

On a Mac with Xcode 26 or later (the demo iPhone needs iOS 26 or later):

1. `open ThinkThrice.xcodeproj`, pick your team under Signing & Capabilities (`DEVELOPMENT_TEAM` is empty and the bundle ID is `com.thinkthrice.app`; change it if it's taken), and run on the iPhone. The first build is slow because ExyteChat pulls in Kingfisher, Giphy and MediaPicker.
2. `cd CalmCore && swift test` runs the core tests. They also run from Xcode if you add the package's test target to the scheme.
3. After editing `project.yml` or adding or removing files under `App/`, run `xcodegen generate` (`brew install xcodegen`) and commit the regenerated project. Adding a file only through Xcode also works, but then `project.yml` is out of date.

The chat's contact header is a Liquid Glass capsule with the avatar initial, an online dot, the name and a status line: 「在线」, or 「正在输入…」 while a scripted reply is on its way (`ChatStore.peerIsTyping`). Scripted peers are always online. In the two-phone conversation the dot and status follow the connection (`ChatStore.presence`): orange 「正在寻找附近的手机…」, green 「在线」, gray 「连接断开，正在重连…」.

Demo controls: in a chat, press and hold the contact header (or 设置 → 打开演示面板) to open the demo panel. A plain tap on the header opens the contact sheet. It can jump to 01:30, fast-forward to 09:00 or by 15 minutes, return to real time, adjust the night and day thresholds with sliders, score any sentence against the live detector for 前任 / 老板 / 其他 (model probability, impulse score, reason, matched words), switch the two-phone mode, and 「清空所有对话」 for a fresh rehearsal (deletes saved conversations, resets the demo clock and thresholds). While the clock is shifted, the header's status line adds 「演示时间 …」.

All timings and thresholds live in `CalmCore/Sources/CalmCore/TimePolicy.swift`: night 22:00–6:00 (moved from 23:00 at Ryan's suggestion), lock line 0.6 day and night (a score ≥ it settles), night settles until 9:00, day settles 15 minutes, 3 ritual pages at night and 1 by day, 5 s per ritual page, 1.5 s per melt-editor piece.

## Motion and haptics

- **Freeze**: a held message first shows as a normal blue bubble, then the colour drains, a frosty glint appears and a glass shell closes around it with a burst of snowflakes (`SettlingBubble.freeze()`), with a heavy-then-rigid haptic. It replays when a rewrite is rescored and still too impulsive.
- **Day and night**: the chat's backdrop is a pale sky by day and a deep violet sky at night (22:00–6:00 on the demo clock), crossfading over 1.2 s; at night the chat and its sheets switch to dark mode.
- **Snow**: flakes fall behind the chat only while a message in it is frozen (`ChatStore.heldCount > 0`).
- **Ritual**: each page shows a breathing flower like the Apple Watch Breathe app: six translucent petals bloom out and turn while breathing in (first half of the 5 s wait) and fold back while breathing out. The ritual sheet is always dark. 「下一题」 unlocks with a light tick.
- **Melt editor**: unrevealed sentences sit in frozen blocks that blur away one by one as they thaw into the editor.
- **Let go**: the bubble breaks into specks of ice that drift up and fade (`IceDust`).
- **Delivery**: a held message turns from glass to solid blue in place, with a success haptic; normal sends get a light tap.
- **Action panel**: shows the impulse score and why (「冲动指数 100 · 深夜想复合 「复合」」, or 「语气激动」 when the model alone decided).
- **List**: avatars, last activity time, and a snowflake badge with how many messages are still held.
- Reduce Motion turns off the burst, the breathing, the dissolve particles and the snow. Haptics only work on a real iPhone.

## Detector (Ryan's model and rules)

Ryan delivered the detector on 2026-11-21 (`ThinkThrice_交付.zip`, model v2c). It has two layers, both on the phone:

- **Model**: `App/Model/ThinkThriceAnger.mlmodel` (Create ML on BERT embeddings, 1.3 MB, labels `angry` / `other`), with `ThinkThriceAngerLite.mlmodel` (MaxEnt, 0.3 MB) as the fallback when the main one won't load. `ThinkThriceClassifier` loads them by these names, so don't rename them. MD5s match the handoff: `1526d5c2…` and `ab1367e4…`.
- **Rules**: `CalmCore/Sources/CalmCore/ThinkThriceRules.swift`, checked top to bottom, first hit wins: 辱骂 (`insult`, anyone, any time) → 怼老板 (`bossRant`, to the boss) → 深夜想复合 / 深夜辞职 (`reconcile` to an ex / `quit` to the boss, late night only) → greetings only (sent) → polite boss messages (never locked by the model alone) → model score `(0.7 × p × 100 + 0.3 × punctuation) × scene factor`, locked at 60.

How the app calls it (`ThinkThriceJudge`, `ChatStore.score`): each conversation has a `recipient` in `Scripts.json` (`ex` for 前任, `boss` for 老板, `other` for 组员 and the two-phone chat), with Ryan's scene factors 2.0 / 1.6 / 1.0. `lateNight` is the demo clock's night (22:00–6:00, as Ryan suggested). The verdict's 0–100 score divided by 100 goes into the state machine, and both `TimePolicy` thresholds default to 0.6, so a message settles exactly when Ryan's verdict says lock. Without any model the rules decide alone.

Ryan's two Swift files are copied unchanged except for `public` and `Sendable` so they can live in CalmCore. To add a word, add a string to the right list in `ThinkThriceRules.swift`, and put words that a short one would wrongly hit into that list's `except`. Then run `cd CalmCore && swift test`: `AcceptanceTests` runs all of Ryan's acceptance sentences (`Fixtures/demo_script.csv`, `boss_probe.csv`, `demo_v2.csv`, judged as late night) through the real main model, and the stage script and boss probe through the Lite model. To add a sentence, add a CSV row (`句子,msg,boss,1.6,lock,备注`).

Not used: `answerStillAngry` (the ritual questions are not answered in this app, as decided in the plan). Known weak spots, from Ryan's notes, so keep them off stage: indirect make-up lines (「你还会想起我吗」), calm errands to an ex can lock (「你的伞还在我这…」), sarcasm (「行，你开心就好」), ordinary venting locks (「堵车堵了一小时气死我了」), and with the Lite fallback 「晚安，早点睡」 to an ex locks.

Stage script (all verified): 老板 「老板我今天需要请一个病假」 sends; 老板 「你是不是脑子有问题？天天让人加班」 locks; 前任 「在吗」 sends; 前任 「我想复合了」 locks **only at night**, so jump the demo clock to 01:30 first (the demo panel's 「跳到 01:30」 is the 「强制深夜」 switch Ryan asks for).

Risk to check on the iPhone: the main model runs on the system's Chinese BERT embedding (`NLContextualEmbedding`). On a device that has never used it, those assets are missing and the main model returns no prediction at all for every sentence (checked on a fresh cloud Mac: 111 of 111 blank, retries don't help); the first attempt makes the system download them, and about a minute later the same model scores normally (「你懂个屁」 0.86, 「晚安，早点睡」 0.04). Until then only the rules would decide. So: the app requests the assets at launch (`AppModel.prepareEmbeddingAssets`), `ThinkThriceJudge` falls back to the Lite model (which needs no embedding) for any sentence the main model scores exactly 0, and the demo panel's 「中文 BERT 资源」 row must say 已就绪 before going on stage. Open the app on the demo phone with network a few minutes before presenting. `AcceptanceTests` waits for the assets the same way.


Workaround to know about: the plan's fallback was `NLTagger` sentiment, but on macOS 27 `NLTagger` has no sentiment scheme for Simplified Chinese. It is no longer used.

## App shell

- **Avatars**: me, 前任, 老板 and 组员 have 3D cartoon portraits in `App/Assets.xcassets/avatar-<id>` (`me`, `ex`, `boss`, `teammate`); 附近的 TA falls back to an initial. Apple doesn't let apps generate or read Memoji, so these are generated stand-ins: to use a real Memoji, export it from the iPhone as a sticker image and replace the file in that imageset.
- **Tabs**: 聊天, 三思 and 设置. The tab bar hides inside a chat.
- **三思 (progress)**: every step of the settle flow is logged as a `ThinkEvent` (`StatsStore`, `Conversations/stats.json`). The page opens with the week in words, written in the tone of Apple's Health and Screen Time summaries (second person, plain, specific numbers, encouraging, no exclamation marks): a headline (「这周，你更常先停下来。」), a sentence of evidence, a closing line, and up to four highlights (calm streak, messages let go, calm rewrites, time taken, and a gentle tip when the ritual wins). The wording lives in `CalmCore/Sources/CalmCore/ThinkReview.swift` and is unit-tested. Below it come the numbers: the week's 「三思指数」 against last week, tiles for frozen / rewritten / let go / cooled-or-waited, a 14-day chart of messages sent versus frozen, and how frozen messages ended. The index (`ThinkStats.Summary.score`) is half holding less, half handling held messages reflectively (letting go and calm rewrites count fully, waiting and still-impulsive rewrites half, the ritual not at all), plus up to 10 for cooling pauses. On first launch two weeks of example history are seeded so the page isn't empty in a demo; the page says so, and 设置 → 清除示例统计 removes them.
- **设置**: the two lock lines (live), the fixed timings, notification and privacy switches (saved, not wired up yet), clear example stats, clear all conversations, and the demo panel.
- **Profile**: the avatar at the top left of 聊天 opens it: name and signature (editable), this week's index, let-gos and cooling pauses, a global status, share, and badges. Modelled on the Luma profile layout; the Mobbin reference needs a login, so the exact screen wasn't seen.
- **Contact card** (tap the chat header): a glass card that grows down out of the capsule, not a sheet; its height is capped so its bottom stays above the keyboard, and it scrolls when that is short. Tap outside or the chevron to fold it back. It holds the status this side shows the other (在线 / 冷静中 / 忙碌 / 显示离线), call / video / search (front end only) and mute, the cooling switch, note (renames the chat), mute and pin (pins it in the list). Status, note, mute and pin are saved with the conversation.
- **Cooling pause** (the snowflake at the top right, or the contact sheet): for 15 minutes, messages I send are held until it ends (`SettleEvent.hold(until:)`, no scoring, not counted as impulsive) and the other side's replies are kept back; the header shows 「双方冷静中 · 还剩 mm:ss」 and the input says until when. When it ends, held replies arrive and my messages are ready to confirm. Over two phones the other side doesn't see the pause yet: only text crosses the wire.

## Persistence

Each conversation is saved as JSON in Application Support (`Conversations/<id>.json`) after every change: the other side's messages, my messages as full `CalmMessage` records, and how far the script has got. The demo clock offset, the thresholds and the two-phone role go into `UserDefaults` (`DemoSettings`).

This is a plain snapshot instead of the planned SwiftData model: `CalmMessage` was already `Codable`, nothing is queried, and the reducer stays the only thing that changes a record. On launch each record goes through the reducer's `.relaunched` event: a message that was in the ritual, confirm, rewrite or rescore sheet goes back to settling (or ready, if its countdown passed), a dissolving one is gone, and one that was still being scored is scored again. Pending local notifications are the system's and survive on their own.

## Two phones (optional)

Not MultipeerConnectivity (deprecated; TN3151, TN3213). `P2PTransport` implements `MessageTransport` with iOS 26's Network.framework:

- The host advertises Bonjour `_calmchat._tcp` with `NetworkListener` (one connection at a time); the joiner finds it with `NetworkBrowser` and connects with `NetworkConnection`. Both use `Coder(WireMessage.self, using: .json) { TCP() }` with `peerToPeerIncluded(true)`, so the phones talk over Apple peer-to-peer Wi-Fi without the venue network. After a drop the host keeps listening and the joiner searches again every 2 s.
- Only delivered messages are passed to `send`, so held text never leaves the phone.
- `NSLocalNetworkUsageDescription` and `NSBonjourServices` are in `project.yml` under `info:`; the first connection triggers the local network permission prompt on both phones.
- To use it: open the demo panel on both phones, choose 「等待连接」 on one and 「加入」 on the other, and open 「附近的 TA」 in the conversation list. To fall back on site, choose 「关闭」 and demo with the scripted conversations.
- It compiles against the iOS 27.3 SDK but has never run: the simulator can't do peer-to-peer Wi-Fi, so it needs two real iPhones. Things to check first: the permission prompt, discovery with Wi-Fi on but not joined to a network, reconnecting after one phone locks, and that switching the role while inside 「附近的 TA」 needs going back to the list (the conversation is rebuilt).
- No typing indicator or read receipts cross the wire; the header only shows the connection.

## Known issues

- Fixed: delivered Chinese messages near one line long used to be cut off with 「…」 in exyte's default bubble (exyte measures text with UIKit, which comes out narrower than SwiftUI's rendering of full-width punctuation, and then applies `lineLimit(1)`). Outgoing messages now use our own `DeliveredBubble`.
- A message delivered after settling stays where it was written, it turns from glass to solid in place (skipped with Reduce Motion); the scripted reply appears below it.
- Local notifications use a time-interval trigger computed from the demo clock offset (real fire time = `settleUntil` − offset). Moving the clock reschedules them. Check on a device that the 「昨晚 1:47 的那条沉淀好了」 banner appears, including in the foreground.
- Questions and scripted replies are draft copy for the non-tech teammates to replace in `App/Resources/*.json`. When a script runs out, the other side goes quiet.

## Needs a Mac or iPhone to verify

- Real-device run on iOS 26: signing, keyboard avoidance with the custom input bar, Liquid Glass rendering, performance.
- Notification permission prompt and banners on a device.
- Core ML latency and size with Ryan's real model (target: tens of milliseconds).
- Whether `NLTagger` sentiment supports Chinese on iOS (expected: no).
- The two-phone mode, end to end.

## Next steps

1. Sean: open on a Mac, set the team, run on the demo iPhone, and try the demo panel flow once.
2. On the iPhone, check the demo panel's 模型 row says `ThinkThriceAnger` (not the Lite fallback), then rehearse Ryan's stage script.
3. Try the two-phone mode on two iPhones (see Two phones) and decide whether it goes into the demo.
4. M4 polish and accessibility pass; replace draft copy; build the demo sentence list into a rehearsal script.
