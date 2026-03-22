# CDP Upload TODO

## 現状
- cdp-bridge各callが新建WebSocket接続を作るため、nodeId/objectIdがcall間で無効化
- DOM.querySelectorが "Could not find node" で失敗
- Runtime.evaluate + DataTransfer はローカルファイルパス設定不可

## 解決ルート

### D2（優先・現行stackで試す）
Input.dispatchDragEvent(files) でファイルドロップをシミュレート

1. **[ ] smoke/drag-drop-smoke.md実装**
   - Input.dispatchDragEvent(dragEnter → dragOver → drop, files:[zipPath])
   - 結果: input.filesまたは添付chip変化確認

2. **[ ] smoke/drop-point-resolution.md実装**
   - Runtime.evaluate(returnByValue:true)でcomposer近傍のdrop座標取得
   - `#prompt-textarea` または `form` の中心座標

3. **[ ] 実装テスト**
   - qjs upload_by_drop.mjs 作成
   - cdp-bridge call 連続実行でdrag event送信

### D1（D2失敗時・cdp-bridge修正必要）
永続WebSocket接続でobjectId使用

4. **[ ] cdp-bridge永続セションモード追加**
   - 現在: call毎に新WS接続
   - 変更: sessionオープン→複数request→sessionクローズ

5. **[ ] integration/persistent-objectid-to-setfile.md実装**
   - Runtime.evaluate("document.getElementById('upload-files')")
   - objectId取得 → DOM.setFileInputFiles(files, objectId)
   - 同一WS接続で実行

### C（fallback）
Page.setInterceptFileChooserDialog + click

6. **[ ] integration/filechooser-backendnodeid.md実装**（補助）
   - 可視要素クリックでchooser開く
   - Page.fileChooserOpened.backendNodeId使用

## 完了条件
- [ ] D2でファイル添付成功または
- [ ] D1実装でファイル添付成功

## 現在のブランチ
- cdp-upload（origin/devから作成）

## 一時ファイル削除
- [ ] tmp_*.mjs削除済み
- [ ] /tmp/hq-amp-*削除（オプション）