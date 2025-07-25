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

# 設定管理
./ado-tracker.sh config show      # 設定表示
./ado-tracker.sh config validate  # 設定検証
./ado-tracker.sh config template  # テンプレート生成

# チケット履歴を取得（実装予定）
./ado-tracker.sh fetch ProjectName 30
```

## テスト実行

```bash
# 基本テスト
./test_ado_tracker.sh

# 高度な設定テスト
./test_config_advanced.sh
```