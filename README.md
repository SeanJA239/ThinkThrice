# ThinkThrice

An iOS chat app for the CPX hackathon (Track 2, reverse UX). Messages that an on-device model scores as impulsive don't send right away: they settle on the device, and the user can take a ritual to send tonight, wait until morning, rewrite in a melt editor, or let go.

## Usage

Requires Xcode 26 or later and an iPhone on iOS 26 or later.

1. Open `ThinkThrice.xcodeproj`, choose your team under Signing & Capabilities, and run the `ThinkThrice` scheme on the iPhone.
2. Run the core tests with `cd CalmCore && swift test` on a Mac.
3. In a chat, triple-tap the contact header to open the demo panel (demo clock, thresholds, scorer probe, two-phone mode, reset).

The trained model goes in `App/Model/ImpulseClassifier.mlmodel`. Until it's there, a keyword scorer stands in.

See [docs/HANDOFF.md](docs/HANDOFF.md) for the current status, structure, the model contract and next steps.
