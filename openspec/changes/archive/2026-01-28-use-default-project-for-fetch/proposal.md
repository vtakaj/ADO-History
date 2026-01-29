## Why

fetch コマンド実行時に毎回プロジェクト名を引数で指定する必要があり、.env に AZURE_DEVOPS_PROJECT が定義されているにもかかわらず二重指定になっている。この無駄な指定をなくし、使い勝手を向上させるとともに入力ミスを減らしたい。

## What Changes

- fetch コマンドのパラメータからプロジェクト名引数を削除する
- fetch コマンド実行時は .env の AZURE_DEVOPS_PROJECT を既定プロジェクトとして使用する
- AZURE_DEVOPS_PROJECT が未設定の場合は明示的にエラーとし、設定方法を案内する

## Capabilities

### New Capabilities
- `fetch-default-project`: fetch コマンドが .env の AZURE_DEVOPS_PROJECT を既定プロジェクトとして利用し、プロジェクト名の引数なしで実行できるようにする

### Modified Capabilities
- `fetch-command-cli`: fetch コマンドのインターフェース仕様を見直し、プロジェクト指定方法を「環境変数による既定値」に統一する（既存の positional 引数は廃止）

## Impact

- CLI インターフェースの変更: `./ado-tracker.sh fetch <ProjectName> <days>` から、原則として `./ado-tracker.sh fetch <days>`（AZURE_DEVOPS_PROJECT 前提）に移行する
- 設定依存の明確化: .env の AZURE_DEVOPS_PROJECT が必須に近い位置づけになり、設定検証ロジックの強化が必要
- テストコードへの影響: fetch 関連のユニットテスト・結合テストで、プロジェクト引数を前提としているケースを見直し、デフォルトプロジェクト前提のパターンを追加・更新する
- ドキュメント更新: README やヘルプ出力で fetch コマンドの使い方を「デフォルトプロジェクト使用」を前提とした説明に更新する

