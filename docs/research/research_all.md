# Azure DevOps 作業実績抽出ツール 技術スタック調査報告書

## 調査概要
現行実装は Bash を中心としたシンプル構成で、`ado-tracker.sh` をエントリーポイントに複数モジュールへ分割されています。Azure DevOps REST API から Work Item とステータス履歴を取得し、月次の作業記録テーブル（Markdown）を生成します。

## 技術スタック
- bash
- curl (Azure DevOps API 呼び出し)
- jq (JSON 処理)
- awk/sed (テキスト処理)
- date (日付計算)

**注意:** jq は環境によっては事前インストールが必要です。

## 実装構成
```
ado-tracker.sh          # エントリーポイント（コマンドルーター）
lib/core/               # API クライアント、設定、データ処理、ログ
lib/commands/           # サブコマンド実装
lib/formatters/         # 表示/Markdown 出力
lib/utils/              # 日付・文字列・ファイル・バリデーション
DATA_DIR=./data/        # 取得データ保存先
work_records/           # 作業記録テーブル出力先
```

## コマンド一覧（現行実装）
```bash
./ado-tracker.sh fetch <project> [days] [--with-details]
./ado-tracker.sh status-history <project>
./ado-tracker.sh fetch-details <project>
./ado-tracker.sh generate-work-table <YYYY-MM> <file>
./ado-tracker.sh test-connection
./ado-tracker.sh config show|validate|template
```

## データ保存
```
./data/workitems.json
./data/status_history.json
./data/workitem_details.json   # --with-details または fetch-details 実行時のみ
./data/backup/                 # 自動バックアップ
./data/checkpoint.json         # 中断復旧用チェックポイント
```

## 作業記録テーブル生成
- 出力形式: Markdown
- 出力先: `./work_records/YYYY-MM.md`
- 対象者の絞り込み:
  - コマンドの `--assignees` 指定
  - もしくは `.env` の `WORK_TABLE_ASSIGNEES` を使用

## 実行手順（例）
```bash
# 事前に .env を用意（AZURE_DEVOPS_PAT, AZURE_DEVOPS_ORG など）

# 直近30日を取得
./ado-tracker.sh fetch MyProject 30

# 詳細も含めて取得
./ado-tracker.sh fetch MyProject 30 --with-details

# 月次作業記録テーブル生成
./ado-tracker.sh generate-work-table 2025-12 ./work_records/2025-12.md
```

## 自動化（例）
`auto-report` の専用コマンドは現行実装にありません。cron 等で `fetch` と `generate-work-table` を連続実行する形で自動化します。

```bash
# 月初に前月分を生成する例
0 9 1 * * /path/to/ado-tracker.sh fetch MyProject 40 && \
  /path/to/ado-tracker.sh generate-work-table 2025-12 /path/to/work_records/2025-12.md
```

## セキュリティ
- PAT は環境変数（.env）で管理し、コミットしない
- `.env` の推奨権限は 600
- ログには機密情報を出さない

## 備考（未実装）
- `calculate`, `summary`, `auto-report`, `export` などのコマンドは現行実装に存在しません
- CSV/Excel/JSON へのエクスポートは未対応（Markdown 出力のみ）
