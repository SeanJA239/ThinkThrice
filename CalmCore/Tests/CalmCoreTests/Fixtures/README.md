# Test fixtures

`demo_script.csv`, `boss_probe.csv` and `demo_v2.csv` are the model side's acceptance sentences, copied unchanged from the handoff package (`ThinkThrice_交付/验收/`, 2026-11-21). `AcceptanceTests` runs every row through `ThinkThriceRules` with the real models in `App/Model/`, the same way the handoff's `验收工具` does.

Columns: `text,kind,to,ctx,expect,note`. `kind` is `msg` (expect `lock` / `send`, judged as late night), `answer` (expect `angry` / `calm`) or `limit` (known limitation, not checked). Lines starting with `#` are section titles. Don't put an ASCII comma inside a sentence.

To add a sentence the app must hold or send, add a row to one of these files and run `swift test`.
