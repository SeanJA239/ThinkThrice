# Test fixtures

`TinyImpulse.mlmodel` is a toy Create ML text classifier (MaxEnt, 30 sentences) with the agreed labels `impulsive` and `calm`. It exists only so `CoreMLScorerTests` can check the integration contract: `NLModel` loads the model and `predictedLabelHypotheses` returns a probability for `impulsive`. It is not the app's model and must not be shipped in the app.

It was made with `MLTextClassifier(trainingData: ["impulsive": [...], "calm": [...]])` and `write(to:metadata:)` on macOS.
