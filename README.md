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

## エラーハンドリングとログ機能（US-001-BE-005）

### 強化されたエラーハンドリング

Azure DevOps API呼び出し時の各種エラーに対して詳細な対処法を提供：

- **401 認証エラー**: PAT有効期限、アクセス権限、組織名の確認を提案
- **403 権限エラー**: PAT権限設定、プロジェクト参加状況の確認を提案
- **404 リソースエラー**: プロジェクト名、組織名、Work Item IDの確認を提案
- **429 レート制限**: Retry-Afterヘッダーを解析して適切な待機時間を設定
- **5xx サーバーエラー**: Azure DevOpsサービス状況の確認と再実行を提案
- **ネットワークエラー**: 接続状況、プロキシ設定、タイムアウト値の調整を提案

### 指数バックオフリトライ機能

- 初期遅延時間から開始し、失敗するたびに遅延時間を2倍に増加
- 最大遅延時間（300秒）に達するまで継続
- レート制限時はRetry-Afterヘッダーを優先して使用

### チェックポイント機能

処理中断時の復旧機能：

```bash
# 処理中断後、同一コマンドを再実行すると自動復旧
./ado-tracker.sh fetch MyProject 30

# チェックポイントファイルの場所
./data/checkpoint.json
```

### タイムスタンプ付きログ

すべてのログメッセージにタイムスタンプが付与：

```
[2025-07-25 01:30:00] [INFO] API呼び出し: GET https://dev.azure.com/org/project/_apis/wit/workitems
[2025-07-25 01:30:01] [WARN] レート制限: 60秒後にリトライします (HTTP 429)
[2025-07-25 01:30:02] [ERROR] 認証エラー: PATを確認してください
```

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

# 詳細情報も含めて取得
./ado-tracker.sh fetch ProjectName 30 --with-details  # 詳細情報も含めて包括的に取得

# ステータス変更履歴のみを取得
./ado-tracker.sh status-history ProjectName  # 既存Work Itemsのステータス変更履歴を取得

# Work Item詳細情報のみを取得
./ado-tracker.sh fetch-details ProjectName  # 既存Work Itemsの詳細情報を取得
```

## 機能詳細

### Work Items取得 (fetch)

指定されたプロジェクトのWork Items（チケット）とステータス変更履歴を取得し、JSON形式でローカルに保存します。

#### 基本動作
通常のfetchコマンドでは以下の情報を取得します：
- **基本情報**: チケット番号（ID）、タイトル、担当者、現在のステータス、最終更新日時
- **ステータス履歴**: 各チケットのステータス変更履歴

#### 詳細情報オプション
`--with-details` オプションを指定すると、追加で詳細情報も取得されます：
- **詳細情報**: チケット種別、優先度、作成日時、見積もり時間、説明等

#### データ保存
- 基本情報: `./data/workitems.json`
- ステータス履歴: `./data/status_history.json`
- 詳細情報: `./data/workitem_details.json`（--with-detailsオプション使用時のみ）
- 既存データは `./data/backup/` に自動バックアップされます
- ページネーション対応で大量データも処理可能

#### 使用例
```bash
# プロジェクト "MyProject" の過去30日間の基本データを取得
./ado-tracker.sh fetch MyProject 30

# 詳細情報も含めて包括的に取得
./ado-tracker.sh fetch MyProject 30 --with-details

# 過去7日間の基本データを取得
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

# fetchコマンドで詳細情報を含めて取得するには --with-details オプションを使用
./ado-tracker.sh fetch MyProject 30 --with-details
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