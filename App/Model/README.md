# Models

`ThinkThriceAnger.mlmodel` (main) and `ThinkThriceAngerLite.mlmodel` (fallback) are the model side's detector, delivered 2026-11-21. `ThinkThriceClassifier` loads them by these names, so don't rename them; Xcode compiles them into the app bundle. The keyword rules are in `CalmCore/Sources/CalmCore/ThinkThriceRules.swift`. See `docs/HANDOFF.md` → Detector.
