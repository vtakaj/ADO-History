## Implementation tasks for use-default-project-for-fetch

- [x] fetch コマンドの引数パースを「デフォルトプロジェクト前提」に変更する
  - [x] `ado-tracker.sh` の `fetch` サブコマンドで、`cmd_fetch` への引数を `days` のみ渡すように見直す
  - [x] `lib/commands/fetch.sh` の `cmd_fetch` 実装を、プロジェクト名を positional 引数から受け取らず、`AZURE_DEVOPS_PROJECT` から取得する形に変更する
  - [x] `AZURE_DEVOPS_PROJECT` を使っていることが分かる INFO ログを追加する（例: 「プロジェクト: <name> (from AZURE_DEVOPS_PROJECT)」）

- [x] 設定検証に AZURE_DEVOPS_PROJECT を追加する
  - [x] `lib/core/config_manager.sh` の `validate_config()` に、`AZURE_DEVOPS_PROJECT` 未設定・空文字時のエラーチェックを追加する
  - [x] エラーメッセージに「.env に AZURE_DEVOPS_PROJECT を設定する」案内を含める

- [x] エラーハンドリング／ログの強化
  - [x] `AZURE_DEVOPS_PROJECT` が存在しないプロジェクト名だった場合（API 404 など）に、プロジェクト名と組織名の確認を促すメッセージを追加する

- [x] テストの追加・更新
  - [x] ユニットテスト（`tests/unit`）で、`AZURE_DEVOPS_PROJECT` 設定済み＋`fetch 30` が成功するケースを追加する
  - [x] ユニットテストで、`AZURE_DEVOPS_PROJECT` 未設定／空文字時にエラーになるケースを追加する
  - [x] 結合テスト（`tests/integration`）で、fetch 関連のシナリオを「プロジェクト引数なし（AZURE_DEVOPS_PROJECT 前提）」に合わせて更新する

- [x] ドキュメント・テンプレートの更新
  - [x] `.env.template` の `AZURE_DEVOPS_PROJECT` の説明に「fetch コマンドのデフォルトプロジェクトとして利用される」ことを追記する
  - [x] `README.md` の fetch コマンド使用例を、`./ado-tracker.sh fetch <days>`（AZURE_DEVOPS_PROJECT 前提）の形に更新する
