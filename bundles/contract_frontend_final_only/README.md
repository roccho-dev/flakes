# contract_frontend_semantic_ir_tdd

この bundle は final-only です。正の入口は semantic core / provenance audit / runtime black-box contract の3系統だけです。

## これは何か

strict contract を 2 profile で検証します。

- semantic core: target の意味条件と target graph を検証する
- provenance audit: decomposition run / origin / revision branching を検証する
- runtime suite: 同じ facts に対して core と audit の verdict が適切に分離されていることを検証する

raw narrative はこの bundle に直接入れません。bundle が受け取るのは strict DSV facts だけです。

## 正の入口

- 全部回す: `./bin/run_all.sh`
- infra green: `./bin/run_infra_green.sh`
- core red: `./bin/run_core_red.sh`
- core green: `./bin/run_core_green.sh`
- audit red: `./bin/run_audit_red.sh`
- audit green: `./bin/run_audit_green.sh`
- runtime suite: `./bin/run_runtime_suite.sh`
- final-only gate: `./bin/run_final_only_gates.sh`

## 先に見る資料

- 使い方: [HOWTOUSE.md](./HOWTOUSE.md)
- 最終仕様: [docs/FINAL_SPEC.tsv](./docs/FINAL_SPEC.tsv)
