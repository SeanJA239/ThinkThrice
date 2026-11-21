# Model drop-in

Put the Create ML text classifier here as `ImpulseClassifier.mlmodel` (labels `impulsive` and `calm`). Xcode compiles it into the app bundle, and `AppModel` loads it with `CoreMLScorer(bundledModelNamed: "ImpulseClassifier")`. When the file is missing, the app falls back to `KeywordScorer`. The debug panel shows which scorer is live. See `docs/HANDOFF.md`.
