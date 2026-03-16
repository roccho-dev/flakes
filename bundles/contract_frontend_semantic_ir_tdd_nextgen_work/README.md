# contract_frontend_semantic_ir_tdd

この README は入口だけを案内します。実際の使い方は **[HOWTOUSE.md](./HOWTOUSE.md)** を読んでください。

## これは何か

この bundle は、次の約束が壊れていないかを機械的に確かめるための実行可能テストです。

- 目的・事象から契約フロントエンドへ落とした意味が欠けていないか
- backend に落とせる集合意味 IR になっているか
- lowering path に backend / mode / feature / artifact identity が揃っているか
- exactness / soundness の根拠が足りているか
- whole-system target で goal/event → artifact → witness → usecase の trace が切れていないか
- adequacy obligation が未接続ではないか
- runtime / quality obligation が未接続ではないか

## 最初に使う入口

- legacy 一括実行: `./bin/run_red_green.sh`
- legacy red: `./bin/run_red.sh`
- legacy green: `./bin/run_green.sh`
- nextgen 一括実行: `./bin/run_nextgen_all.sh both`
- nextgen cutover check: `./bin/check_nextgen_cutover.sh`

## 先に読むと分かりやすい資料

- 使い方: [HOWTOUSE.md](./HOWTOUSE.md)
- 全体像: [docs/ARCHITECTURE__contract_frontend_semantic_ir_tdd.html](./docs/ARCHITECTURE__contract_frontend_semantic_ir_tdd.html)
- ケース一覧: [docs/TDD_MATRIX.tsv](./docs/TDD_MATRIX.tsv)
- fact 一覧: [docs/SEMANTIC_IR_FACTS.tsv](./docs/SEMANTIC_IR_FACTS.tsv)
- red→green 対応: [docs/RED_TO_GREEN.tsv](./docs/RED_TO_GREEN.tsv)
- 変更意図: [docs/ANALYSIS.md](./docs/ANALYSIS.md)
- nextgen 最終仕様: [docs/NEXTGEN_FINAL_SPEC.tsv](./docs/NEXTGEN_FINAL_SPEC.tsv)
- old→nextgen 対応: [docs/NEXTGEN_PARITY_MATRIX.tsv](./docs/NEXTGEN_PARITY_MATRIX.tsv)
- nextgen 進行計画: [docs/NEXTGEN_MIGRATION_STEPS.tsv](./docs/NEXTGEN_MIGRATION_STEPS.tsv)

## 現在の実行結果

- red: 60 case
- green: 12 case
- 実行入口: shell-only

詳しい手順と、結果の読み方、詰まりやすい点は **[HOWTOUSE.md](./HOWTOUSE.md)** にまとめています。
