# HOWTOUSE

## まず何をするものか

これは、**契約フロントエンド**と**backend-neutral な集合意味 IR**の約束を、まとめて確かめるための bundle です。

平たく言うと、次を見ます。

- 目的・事象から落とした意味が抜けていないか
- backend に落とす前に必要な情報が揃っているか
- lowering path の backend / mode / feature / artifact identity が抜けていないか
- exact と言うなら、その根拠があるか
- whole-system target では goal/event → artifact → witness → usecase の trace が本当に閉じているか
- runtime や品質のテスト義務が、あと回しのまま放置されていないか

## だれ向けか

この bundle は、次の人が使う想定です。

- 契約フロントエンドを設計する人
- Datalog / Nemo ルールを増やす人
- 新しい backend を増やしたい人
- red / green の差分を見ながら仕様を固めたい人

## 使い始める前に見るもの

最初はこの順で見ると迷いにくいです。

1. `README.md`
2. `HOWTOUSE.md`（このファイル）
3. `docs/ARCHITECTURE__contract_frontend_semantic_ir_tdd.html`
4. `docs/TDD_MATRIX.tsv`
5. 必要なら `docs/SEMANTIC_IR_FACTS.tsv`


## nextgen を追うときの最短順

legacy bundle を読むだけでなく、nextgen の分離設計を追うなら次の順が最短です。

1. `docs/NEXTGEN_FINAL_SPEC.tsv`
2. `docs/NEXTGEN_PARITY_MATRIX.tsv`
3. `docs/NEXTGEN_MIGRATION_STEPS.tsv`
4. `rules/nextgen/`
5. `tests_next/`

見る観点は次です。

- semantic strict と provenance strict が混ざっていないか
- implementation が source of truth になっていないか
- old vocabulary が nextgen で split / rename / defer のどれになったか

## nextgen をまとめて回す

nextgen suite 群は `tests_next/SUITES.tsv` に列挙されています。

- 全部回す: `./bin/run_nextgen_all.sh both`
- 個別 suite を回す: `./bin/run_nextgen_suite.sh <suite_name> both`
- cutover gate を確認する: `./bin/check_nextgen_cutover.sh`

legacy path は比較用に残しますが、新しい semantic/provenance responsibility は `rules/nextgen/` と `tests_next/` に追加します。

## 実行に必要なもの

この bundle には `vendor/nmo` が入っています。追加で最低限必要なのは次です。

- `bash`
- `awk`
- `sort`
- `diff`
- Linux x86-64 で実行できる環境

Python は不要です。

## まず最初の実行

全部まとめて確認するなら、bundle のルートでこれを実行します。

`./bin/run_red_green.sh`

意味はこうです。

- `run_red.sh` は「壊したらちゃんと赤になるか」を確認します
- `run_green.sh` は「正しい入力ならちゃんと緑になるか」を確認します
- `run_red_green.sh` は両方まとめて回します

## 結果の見方

### すぐ見る場所

実行後は `results/` の下に出力が作られます。

- `results/red/summary.txt`
- `results/green/summary.txt`
- `results/red/<case_id>/`
- `results/green/<case_id>/`

### PASS と FAIL の意味

- `PASS` は、その case の期待どおりだったという意味です
- `FAIL` は、期待した violation や achieved とズレたという意味です

### 各 case でよく見るファイル

- `Violation.csv`  
  どの違反が出たかを見ます
- `Achieved.csv`  
  どの target / usecase が達成扱いになったかを見ます
- `debug_expected_violation.tsv` と `debug_actual_violation.tsv`  
  red のズレを見るときに使います
- `debug_expected_achieved.tsv` と `debug_actual_achieved.tsv`  
  green のズレを見るときに使います
- `stderr.txt` / `stdout.txt`  
  `nmo` 自体が失敗したときに見ます

## どの資料をいつ見るか

### 仕様をざっと知りたいとき

- `docs/ARCHITECTURE__contract_frontend_semantic_ir_tdd.html`
- `docs/ANALYSIS.md`

### どんな red / green があるか知りたいとき

- `docs/TDD_MATRIX.tsv`
- `docs/RED_TO_GREEN.tsv`

### どんな fact を入れればよいか知りたいとき

- `docs/SEMANTIC_IR_FACTS.tsv`

## いまの bundle で特に押さえる点

この bundle には、レビューで入った修正がすでに反映されています。

### 1. sa08 の強さを下げた

前の案では、「exact-only clause なら必ず proof backend target が必要」と読める形でした。

今はそうしていません。今の実装では、**exactness の根拠があれば受理**します。

受け入れる根拠は次です。

- `ExactnessAnchor`
- `EquivalenceBasis`
- `ProofBackendTarget`

つまり、exact CUE leaf のような既存の exact path と衝突しないようにしてあります。

### 2. quality まわりを分割した

前の案では quality まわりが粗すぎました。

今は次に分かれています。

- `LatencyBudget`
- `CostBudget`
- `AuthzContract`
- `ProductionTraceBinding`

これで「速さ」「コスト」「権限」「本番追跡」が別責務として扱えます。

### 3. fg12 の whole-system trace を実装に合わせた

前の版では、fg12 が広く主張しているのに、rule 側で使っていない fact がありました。

今は `WholeSystemTarget` を使って対象を明示し、次を実際に見ます。

- `GoalEventSource`
- `UseCaseForTarget`
- `ClauseWitnessObligation`
- linked use case の achieved 状態

つまり、whole-system の trace を主張する target だけを、実装でも本当に end-to-end で見ます。

### 4. 実行入口を shell-only に戻した

前の版では entry script の中で Python を呼んでいました。

今は `bin/*.sh` だけで実行します。

### 5. lowering presence を rule にした

前の corrected 版では、lowering path の presence requirement が docs の期待より弱く、次が無くても green になる穴がありました。

- `ClauseBackend`
- `ClauseLoweringMode`
- `ClauseFeature`
- `ClauseArtifact`

今はこれらを red 契約として追加し、whole-system target でも lowered clause の `ClauseArtifact` が無ければ赤になります。

## red を読むときのコツ

red case は「1個の約束を壊して、1個の違反名で検出する」前提で作っています。

なので、まずはその case の ID を見て、次に `ExpectedViolation.tsv` と `Violation.csv` を比べるのがいちばん早いです。

例:

- `fe..` は frontend compile 側
- `ls..` は lowerable set / backend capability 側
- `sa..` は semantic adequacy obligation 側
- `rq..` は runtime / quality obligation 側
- `tr..` は whole-system trace 側
- `fg..` は green case 側

## green を読むときのコツ

green case は「必要な fact を揃えたときに target / usecase が達成されるか」を見るものです。

最初は `fg..` の case から見て、どの fact の組み合わせで `Achieved.csv` が出るかを掴むと理解しやすいです。

## 新しい case を足すときのすすめ方

まずはこの順が安全です。

1. `docs/TDD_MATRIX.tsv` で既存 ID と責務を確認する
2. 追加したい約束が、frontend / lowering / trace / adequacy / runtime-quality のどこかを決める
3. 先に red case を作る
4. その red を通すために rule を足す
5. 最後に green case を足して、過剰検知が無いかを見る

## よくある詰まりどころ

### `Permission denied` が出る

実行権限が落ちている可能性があります。次を確認します。

- `vendor/nmo`
- `bin/_run_suite.sh`
- `bin/run_red.sh`
- `bin/run_green.sh`
- `bin/run_red_green.sh`

### `nmo_error` が出る

まず `results/<suite>/<case_id>/stderr.txt` を見ます。

### macOS などで `vendor/nmo` が動かない

この bundle に入っている `vendor/nmo` は Linux x86-64 向けです。実行環境が違う場合は、その環境で動く `nmo` に差し替える必要があります。

## 最短の使い方

時間が無いときは、これだけで十分です。

1. `./bin/run_red_green.sh`
2. `results/red/summary.txt` と `results/green/summary.txt` を見る
3. 気になる case の `Violation.csv` または `Achieved.csv` を見る
4. 背景を知りたくなったら `docs/TDD_MATRIX.tsv` を開く

## どこまでがこの bundle の責務か

この bundle は、**契約フロントエンドと集合意味 IR の約束を lint / verify する層**です。

つまり、ここで強いのは次です。

- meaning capture の抜け検出
- backend capability と exactness の矛盾検出
- whole-system trace の切断検出
- obligation の未接続検出

逆に、ここで直接やるものではないのは次です。

- 本番相当の runtime 挙動そのものの保証
- 性能やコストの実測そのもの
- 外部障害注入の実行そのもの

それらは別 suite で閉じる想定です。
