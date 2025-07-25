# ADO-History

Azure DevOpsからチケット履歴を抽出するツール

## 設定管理

Azure DevOps Tracker を使用する前に、接続設定を行います。

### 設定テンプレート生成

```bash
# 設定テンプレートを生成
./ado-tracker.sh config template

# .env.template を .env にコピーして編集
cp .env.template .env
# .env ファイルに必要な値を設定

# 設定を確認
./ado-tracker.sh config show

# 設定を検証
./ado-tracker.sh config validate
```

### 環境変数

以下の環境変数が必要です：

#### 必須設定
- `AZURE_DEVOPS_PAT`: Personal Access Token（必須）
- `AZURE_DEVOPS_ORG`: 組織名（必須）

#### オプション設定
- `AZURE_DEVOPS_PROJECT`: プロジェクト名（実行時指定も可）
- `API_VERSION`: Azure DevOps API バージョン（デフォルト: 7.2）
- `LOG_LEVEL`: ログレベル - INFO|WARN|ERROR（デフォルト: INFO）
- `RETRY_COUNT`: API呼び出しリトライ回数（デフォルト: 3）
- `RETRY_DELAY`: リトライ間隔（秒）（デフォルト: 1）
- `REQUEST_TIMEOUT`: APIリクエストタイムアウト（秒）（デフォルト: 30）
- `BATCH_SIZE`: バッチ処理サイズ（デフォルト: 50）

## 基本的な使用方法

```bash
# ヘルプを表示
./ado-tracker.sh help

# API接続テスト
./ado-tracker.sh test-connection   # Azure DevOps API接続テスト

# 設定管理
./ado-tracker.sh config show      # 設定表示
./ado-tracker.sh config validate  # 設定検証
./ado-tracker.sh config template  # テンプレート生成

# チケット履歴を取得
./ado-tracker.sh fetch ProjectName 30  # 過去30日間のWork Itemsとステータス履歴を取得

# ステータス変更履歴のみを取得
./ado-tracker.sh status-history ProjectName  # 既存Work Itemsのステータス変更履歴を取得
```

## 機能詳細

### Work Items取得 (fetch)

指定されたプロジェクトのWork Items（チケット）を取得し、JSON形式でローカルに保存します。

#### 取得される情報
- チケット番号（ID）
- チケットタイトル
- 担当者情報
- 現在のステータス
- 最終更新日時

#### データ保存
- 取得されたデータは `./data/workitems.json` に保存されます
- 既存データは `./data/backup/` に自動バックアップされます
- ページネーション対応で大量データも処理可能

#### 使用例
```bash
# プロジェクト "MyProject" の過去30日間のWork Itemsを取得
./ado-tracker.sh fetch MyProject 30

# 過去7日間のWork Itemsを取得
./ado-tracker.sh fetch MyProject 7
```

### ステータス変更履歴取得 (status-history)

各Work Itemのステータス変更履歴を取得し、日本時間で記録します。

#### 取得される情報
- Work Item ID
- 変更日時（日本時間 JST）
- 変更者情報
- 変更前ステータス
- 変更後ステータス
- リビジョン番号

#### データ保存
- 取得されたデータは `./data/status_history.json` に保存されます
- 既存データは `./data/backup/` に自動バックアップされます
- 変更日時順でソートされます

#### 使用例
```bash
# プロジェクト "MyProject" のステータス変更履歴を取得
./ado-tracker.sh status-history MyProject

# fetchコマンドでは自動的にステータス履歴も同時取得されます
./ado-tracker.sh fetch MyProject 30
```

## テスト実行

```bash
# 基本テスト
./test_ado_tracker.sh

# API機能テスト
./test_api_functions.sh

# Work Items取得機能テスト
./test_workitems_fetch.sh

# ステータス変更履歴機能テスト
./test_status_history.sh

# 高度な設定テスト
./test_config_advanced.sh
```