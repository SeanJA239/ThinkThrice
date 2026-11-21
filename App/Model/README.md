# Model drop-in

Put the Create ML text classifier here as `ImpulseClassifier.mlmodel` (labels `impulsive` and `calm`). Xcode compiles it into the app bundle, and `AppModel` loads it with `CoreMLScorer(bundledModelNamed: "ImpulseClassifier")` and runs it next to the keyword rules in `Resources/Keywords.json`, taking the higher score. When the file is missing, the keyword rules run alone. The debug panel shows which scorer is live. See `docs/HANDOFF.md`.
