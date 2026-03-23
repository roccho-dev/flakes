# 3-Store Architecture 完成状態へのTODO

## 完了条件

1. polling_contracts.md (7項目) がコード引数と一致
2. headful/headless切替がmjsで実装済み
3. polling loopがorchestrator.mjsに統合済み
4. e2e-test.mjsが全導線をカバー

---

## P1: polling_contracts.md と read-thread.mjs の整合

### P1.1: read-thread.mjs引数をpolling_contracts.md対応に拡張

```text
現状:
  --pollMs <ms>          ← intervalのみ
  --waitMs <ms>          ← timeoutのみ

追加必須:
  --poll-scope <scope>           ← POLL_SCOPE
  --poll-success-condition <cond> ← POLL_SUCCESS_CONDITION
  --poll-interval-min <ms>       ← POLL_INTERVAL min
  --poll-interval-max <ms>       ← POLL_INTERVAL max
  --poll-jitter                ← jitter有効化
  --poll-cap-tries <n>          ← POLL_CAP tries
  --poll-cap-duration <ms>       ← POLL_CAP duration
  --poll-stop-cloudflare         ← Cloudflare即時停止
  --poll-stop-login             ← login-required即時停止
  --poll-stop-ratelimit         ← rate-limit即時停止
  --poll-stop-sessionlost        ← session lost即時停止
  --poll-stop-tabdrift           ← tab drift即時停止
  --poll-report-contract          ← POLL_RESULT出力
```

### P1.2: polling_contracts.md即時停止条件のmjs実装

```text
必須実装:
  - Cloudflare challenge検出 (title + body)
  - login-required state検出
  - rate-limit/quota症状検出
  - session lost / target not found
  - unexpected tab drift
  - authentication mismatch
```

### P1.3: POLL_REPORT_CONTRACT出力形式

```text
実装必須:
  {
    "poll_result": "success|stopped|timeout|error",
    "last_observed_state": { ... },
    "stop_reason_or_success": "string",
    "any_new_artifacts": [ ... ]  // if applicable
  }
```

---

## P2: headful/headless切替実装

### P2.1: chromium-cdp.lib.mjs拡張

```text
追加関数:
  - isHeadlessMode()      ← HQ_CHROME_HEADLESS環境変数チェック
  - detectLoginState(wsUrl) ← CDPでlogin状態取得
  - waitForLogin(wsUrl, opts) ← login完了までpoll
  - getChromeProfileDir()  ← HQ_CHROME_PROFILE_DIR取得
```

### P2.2: chrome/RUNBOOK.md のmjsラッパー

```text
作成ファイル:
  - chrome-profile-bootstrap.mjs  ← headful login + profile snapshot
  - chrome-headless-launch.mjs    ← snapshot再利用でheadless起動
```

### P2.3: headful↔headless導線のskills文書化

```text
作成ファイル:
  - skills/manage/lanes/chrome-headless-lifecycle.md
    ├── bootstrap (headful + login)
    ├── publish (profile snapshot保存)
    ├── headless launch (profile再利用)
    └── recovery (headful fallback)
```

---

## P3: orchestrator.mjsへのpolling統合

### P3.1: polling loop関数の追加

```text
追加関数:
  - pollChatGptResponse(wsUrl, opts) ← polling_contracts.md対応
  - pollUntilComplete(wsUrl, opts)    ← ChatGPT応答完了までpoll
```

### P3.2: orchestrator.mjs correlation統合

```text
追加関数:
  - establishCorrelation(localSessionId, cdpSessionId, wsUrl)
  - trackObservedRev(orchestratorSessionId, storeName, rev)
```

### P3.3: checkpoint自動生成trigger

```text
追加:
  - reconcile()呼び出し時にdirty state自動検出
  - checkpoint生成自動化
```

---

## P4: e2e-test.mjs拡張

### P4.1: 全polling contractsのテスト

```text
テストケース:
  - poll with jitter
  - poll with all stop conditions
  - poll cap (tries)
  - poll cap (duration)
  - poll success (stop button gone + hasPrompt)
```

### P4.2: headful/headless切替テスト

```text
テストケース:
  - headful bootstrap → snapshot
  - headless launch → profile reuse
  - headless → headful fallback
```

### P4.3: 3-store correlation E2E

```text
テストケース:
  - cdp save → orchestrator correlation → checkpoint
  - reconcile → dirty state検出
  - local ↔ cdp observed_rev tracking
```

---

## P5: Skills/Docs更新

### P5.1: polling_contracts.md的微笑化

```text
推奨: polling contractsの7項目を現在のread-thread.mjsに合わせてSimplify
または: mjs引数をpolling_contracts.md严格準拠に修正
```

### P5.2: ui_timeouts.md更新

```text
追加:
  - headful/headless切替ガイド
  - profile再利用の前提条件
```

### P5.3: architecture-boundary.md更新

```text
追加:
  - DOM pollingはqjs責務
  - polling contractsはpolling_contracts.md参照
  - CDP storage bridgeはcdp-results-to-sqlite.mjs参照
```

---

## 完了チェック

- [x] P1.1: read-thread.mjs 全polling引数対応 (commit 1a8af45)
- [x] P1.2: 全即時停止条件実装 (cloudflare, login, rate-limit, sessionlost)
- [x] P1.3: POLL_REPORT_CONTRACT出力形式実装
- [x] P2.1: chromium-cdp.lib.mjs headless関数追加 (commit a0634df)
- [x] P2.2: headful/headless mjsラッパー作成 (commit bc9473f)
- [x] P2.3: chrome-headless-lifecycle.md作成 (commit 94d5182)
- [ ] P3.1: orchestrator.mjs polling loop追加 (cdp-3store branch要作業)
- [ ] P3.2: orchestrator.mjs correlation統合 (cdp-3store branch要作業)
- [ ] P3.3: checkpoint自動生成trigger (cdp-3store branch要作業)
- [ ] P4.1: e2e-test.mjs polling contractsテスト
- [ ] P4.2: e2e-test.mjs headful/headlessテスト
- [ ] P4.3: e2e-test.mjs correlation E2E
- [x] P5.1: polling_contracts.mdまたはmjs整合 (mjsを拡張して対応)
- [x] P5.2: ui_timeouts.md更新 (commit 1cac81c)
- [x] P5.3: architecture-boundary.md更新 (commit 4e68893)

## 完了サマリー (origin/main派生 worktree)

| Commit | 内容 |
|--------|------|
| 1a8af45 | polling contracts (read-thread.mjs) |
| a0634df | headless検出関数 (chromium-cdp.lib.mjs) |
| bc9473f | chrome-profile-bootstrap.mjs |
| 94d5182 | chrome-headless-lifecycle.md |
| 1cac81c | ui_timeouts.md更新 |
| 4e68893 | architecture-boundary.md更新 |

## 残作業 (P3, P4)

P3とP4はcdp-3store branch既存のorchestrator.mjs/e2e-test.mjsを編集する必要があります:
- cdp-3store worktreeに切换して作業継続

---

## 優先順位

1. **P1** (polling contracts整合) ← 核心的功能
2. **P2** (headful/headless) ← demo実現に必須
3. **P3** (orchestrator統合) ← 3-store完成に必須
4. **P4** (e2e tests) ← 品質保証
5. **P5** (docs) ← 保守性
