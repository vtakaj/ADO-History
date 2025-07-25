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
./ado-tracker.sh fetch ProjectName 30  # 過去30日間のWork Items、ステータス履歴、詳細情報を取得

# ステータス変更履歴のみを取得
./ado-tracker.sh status-history ProjectName  # 既存Work Itemsのステータス変更履歴を取得

# Work Item詳細情報のみを取得
./ado-tracker.sh fetch-details ProjectName  # 既存Work Itemsの詳細情報を取得
```

## 機能詳細

### Work Items取得 (fetch)

指定されたプロジェクトのWork Items（チケット）、ステータス変更履歴、および詳細情報を包括的に取得し、JSON形式でローカルに保存します。

#### 取得される情報
- **基本情報**: チケット番号（ID）、タイトル、担当者、現在のステータス、最終更新日時
- **ステータス履歴**: 各チケットのステータス変更履歴
- **詳細情報**: チケット種別、優先度、作成日時、見積もり時間、説明等

#### データ保存
- 基本情報: `./data/workitems.json`
- ステータス履歴: `./data/status_history.json`
- 詳細情報: `./data/workitem_details.json`
- 既存データは `./data/backup/` に自動バックアップされます
- ページネーション対応で大量データも処理可能

#### 使用例
```bash
# プロジェクト "MyProject" の過去30日間の全データを取得
./ado-tracker.sh fetch MyProject 30

# 過去7日間の全データを取得
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

### Work Item詳細情報取得 (fetch-details)

各Work Itemの詳細情報を取得し、日本時間で記録します。既存のworkitems.jsonが必要です。

#### 取得される情報
- Work Item ID
- チケットタイトル
- チケットタイプ（User Story、Bug、Task等）
- 優先度
- 作成日時（日本時間 JST）
- 最終更新日時（日本時間 JST）
- 見積もり時間（原始見積）
- 担当者
- 現在のステータス
- 説明（オプション）

#### データ保存
- 取得されたデータは `./data/workitem_details.json` に保存されます
- 既存データは `./data/backup/` に自動バックアップされます
- バッチ処理による高速取得

#### 使用例
```bash
# プロジェクト "MyProject" のWork Item詳細情報を取得
./ado-tracker.sh fetch-details MyProject

# fetchコマンドでは自動的に詳細情報も同時取得されます
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

# Work Item詳細情報機能テスト
./test_workitem_details.sh

# 高度な設定テスト
./test_config_advanced.sh
```