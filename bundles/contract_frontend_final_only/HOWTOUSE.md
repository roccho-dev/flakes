# HOWTOUSE

## 概要

この bundle は shell-only で動く strict contract verifier です。profile は 2 つです。

- semantic core
- provenance audit

runtime suite は同じ入力 facts に対して core と audit の verdict を黒箱で比較します。

## 必要なもの

- bash
- awk
- sort
- diff
- Linux x86-64 実行環境
- `vendor/nmo` または `NMO` 環境変数または `PATH` 上の `nmo`

解決順は `NMO` env → `vendor/nmo` → `PATH` です。Python は不要です。

## 入口

- `./bin/run_all.sh`
- `./bin/run_infra_green.sh`
- `./bin/run_core_red.sh`
- `./bin/run_core_green.sh`
- `./bin/run_audit_red.sh`
- `./bin/run_audit_green.sh`
- `./bin/run_runtime_suite.sh`
- `./bin/run_final_only_gates.sh`

## 結果の置き場所

実行結果は `results/` に出ます。生成物なので git 追跡対象ではありません。

- `results/infra_import/`
- `results/core/red/`
- `results/core/green/`
- `results/audit/red/`
- `results/audit/green/`
- `results/runtime/`

## 何を strict facts として入れるか

semantic core 側の最小 public vocabulary は次です。

- `Target`
- `TargetPopulation`
- `EventAnchor`
- `ClockSource`
- `ObservationWindow`
- `SuccessMetricIdentity`
- `Refines`
- `Dependency`
- `ExactTarget`
- `EvidenceObligation`

provenance audit 側の最小 public vocabulary は次です。

- `DecompositionRun`
- `SourceRecord`
- `OriginSource`
- `OriginTarget`
- `OriginView`
- `RunEmitsTarget`
- `SupersedesRun`

## 方針

- semantic verdict は provenance 欠落で落とさない
- provenance 問題は audit profile で落とす
- final goal は永続 fact にしない
- decomposition origin は run ごとの provenance として持つ
