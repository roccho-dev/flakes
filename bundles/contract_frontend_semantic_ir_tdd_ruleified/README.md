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

- 全部まとめて回す: `./bin/run_red_green.sh`
- red だけ回す: `./bin/run_red.sh`
- green だけ回す: `./bin/run_green.sh`
- 外部 `nmo` を明示して回す: `NMO=/path/to/nmo ./bin/run_red_green.sh`

`nmo` の決定順は次です。

- `NMO` 環境変数
- `vendor/nmo`
- `PATH` 上の `nmo`（軽量 zip のように `vendor/` を省いた配置向け）

NixOS で bundle 同梱の `vendor/nmo` を使わずに外部バイナリへ差し替えるときは、たとえば `NMO=/run/current-system/sw/bin/nmo ./bin/run_red_green.sh` の形で実行します。

## 最小 facts で回したいとき

rule が大量の `@import ... tsv { resource = "..." }` を持っていても、空 TSV を手で複製する必要はありません。`bin/mk_import_dir.sh` が rule の `@import` だけを見て、足りない resource を空 TSV で補完した import 用ディレクトリを作れます。

- 実行入口: `./bin/mk_import_dir.sh rules/contract_frontend_semantic_ir.nemo <facts_dir> <out_import_dir>`
- suite 実行時は `bin/_run_suite.sh` がこの手順を自動で通します

## 先に読むと分かりやすい資料

- 使い方: [HOWTOUSE.md](./HOWTOUSE.md)
- 全体像: [docs/ARCHITECTURE__contract_frontend_semantic_ir_tdd.html](./docs/ARCHITECTURE__contract_frontend_semantic_ir_tdd.html)
- ケース一覧: [docs/TDD_MATRIX.tsv](./docs/TDD_MATRIX.tsv)
- fact 一覧: [docs/SEMANTIC_IR_FACTS.tsv](./docs/SEMANTIC_IR_FACTS.tsv)
- red→green 対応: [docs/RED_TO_GREEN.tsv](./docs/RED_TO_GREEN.tsv)
- 変更意図: [docs/ANALYSIS.md](./docs/ANALYSIS.md)

## 現在の実行結果

- red: 60 case
- green: 12 case
- 実行入口: shell-only
- 追加依存: なし（Python 追加なし）

詳しい手順と、結果の読み方、詰まりやすい点は **[HOWTOUSE.md](./HOWTOUSE.md)** にまとめています。
