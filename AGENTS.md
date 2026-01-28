# AGENTS.md

このリポジトリで作業するエージェント向けの短いガイドです。

## プロジェクト概要
- Azure DevOps の Work Item とステータス履歴を取得し、作業記録テーブルを生成する Bash ツール
- エントリポイント: `./ado-tracker.sh`
- 取得データは `./data/` に JSON として保存、作業記録は `./work_records/` に出力

## 主要構成
- `ado-tracker.sh`: コマンドルーター（軽量）
- `lib/core/`: API クライアント、設定、データ処理、ログ
- `lib/commands/`: 各サブコマンドの実装
- `lib/formatters/`: 表示/マークダウン出力
- `lib/utils/`: 日付・文字列・ファイル・バリデーション
- `tests/`: unit / integration テスト

## 主要コンポーネント
1. **API クライアント** (`lib/core/api_client.sh`): Azure DevOps REST API 呼び出し、リトライ/レート制限
2. **データ処理** (`lib/core/data_processor.sh`): ステータス履歴抽出・変換
3. **設定管理** (`lib/core/config_manager.sh`): 環境変数の読み込み/検証
4. **ログ** (`lib/core/logger.sh`): タイムスタンプ付きログ出力

## データフロー
1. 設定読み込みと検証
2. Work Items 取得
3. ステータス変更履歴取得
4. `./data/` に JSON 保存（自動バックアップあり）
5. `generate-work-table` で Markdown 出力

## 必須/関連の環境変数
必須:
- `AZURE_DEVOPS_PAT`
- `AZURE_DEVOPS_ORG`

任意:
- `AZURE_DEVOPS_PROJECT`
- `API_VERSION` (default 7.2)
- `LOG_LEVEL` (INFO|WARN|ERROR)
- `RETRY_COUNT`, `RETRY_DELAY`, `REQUEST_TIMEOUT`, `BATCH_SIZE`

## よく使うコマンド
```bash
# ヘルプ
./ado-tracker.sh help

# 接続テスト
./ado-tracker.sh test-connection

# 設定
./ado-tracker.sh config show
./ado-tracker.sh config validate
./ado-tracker.sh config template

# 取得（プロジェクト未指定時はAZURE_DEVOPS_PROJECTを使用）
./ado-tracker.sh fetch ProjectName 30
./ado-tracker.sh fetch 30 --with-details
./ado-tracker.sh status-history
./ado-tracker.sh fetch-details

# 作業記録テーブル生成
./ado-tracker.sh generate-work-table 2025-01 ./work_records/2025-01.md
```

## テスト
```bash
./tests/integration/test_main.sh
./tests/integration/test_work_table.sh
./tests/integration/test_error_scenarios.sh
./tests/integration/test_fetch_flow.sh
./tests/unit/test_api.sh
./tests/unit/test_config.sh
./tests/unit/test_data.sh
./tests/unit/test_output.sh
```
※ テストはモック API を使用するため、実際の Azure DevOps 接続は不要です。

## 実行時の注意
- すべてのシェルスクリプトは `set -euo pipefail` 前提
- 取得データは `./data/backup/` に自動バックアップ
- 中断復旧用のチェックポイント: `./data/checkpoint.json`
- 取得データのタイムスタンプは JST 前提
- PAT などの秘密情報はコミットしないこと（漏洩時は即ローテーション）
