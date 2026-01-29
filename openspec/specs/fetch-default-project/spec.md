# Capability: fetch-default-project

## Overview

fetch コマンドにおいて、プロジェクト名の明示的な引数を省略した場合に、`.env` に定義された AZURE_DEVOPS_PROJECT を既定プロジェクトとして使用して Work Item を取得できるようにする。

## Goals

- 毎回プロジェクト名をコマンド引数で指定しなくても、決め打ちのプロジェクトを対象に fetch できるようにする
- `.env` の AZURE_DEVOPS_PROJECT を唯一のデフォルトプロジェクトとして扱い、二重指定をやめる
- デフォルトプロジェクトが未設定・不正な場合には、明示的で分かりやすいエラーを返す

## Non-goals

- 複数プロジェクトをまたいだ一括 fetch（マルチプロジェクトサポート）は行わない
- 既存の Azure DevOps API 側の権限やレート制限の扱いは変更しない
- fetch 以外のコマンド（status-history, fetch-details, generate-work-table 等）の挙動は、この capability では変えない

## Use cases

1. `.env` に AZURE_DEVOPS_PROJECT=Kurohebi が設定されている環境で、
   - `./ado-tracker.sh fetch 30`
   - と実行すると、プロジェクト Kurohebi の過去 30 日分の Work Item とステータス履歴を取得できる

2. 毎回同じプロジェクトで作業している開発者が、コマンド履歴から fetch を再利用する際に、
   - 以前は `./ado-tracker.sh fetch Kurohebi 30` のようにプロジェクト名を含めていたが、
   - 変更後は `./ado-tracker.sh fetch 30` だけで同じ結果が得られる

## Behavior

### 正常系

- 前提
  - `.env` に AZURE_DEVOPS_PAT, AZURE_DEVOPS_ORG が正しく設定されている
  - `.env` に AZURE_DEVOPS_PROJECT が非空で設定されている

- 実行例
  - `./ado-tracker.sh fetch 30`
    - days 引数のみを受け取り、プロジェクト名はコマンド引数からは受け取らない
    - 内部では AZURE_DEVOPS_PROJECT の値をプロジェクト名として使用する
    - 既存の fetch と同様に、対象プロジェクトの Work Item とステータス履歴を取得し、`./data/*.json` に保存する

- 結果
  - 取得されるデータの内容と保存形式は、従来の fetch（プロジェクト明示指定あり）の場合と同じである
  - ログには、使用したプロジェクト名（AZURE_DEVOPS_PROJECT の値）が INFO レベルで出力される

### エラー系

1. AZURE_DEVOPS_PROJECT が未設定の場合
   - 条件
     - `.env` に AZURE_DEVOPS_PROJECT が存在しない、または空行のみで定義されている
   - 挙動
     - fetch コマンド実行時に設定検証で検出し、エラー終了とする
     - エラーメッセージの例
       - 「AZURE_DEVOPS_PROJECT が設定されていません。.env にデフォルトプロジェクトを設定してください。」
     - どのファイルにどのキーを追加すべきかを、メッセージ内または README への参照で案内する

2. AZURE_DEVOPS_PROJECT が不正な値の場合
   - 条件
     - 文字列としては設定されているが、Azure DevOps API 側で存在しないプロジェクトとして扱われる（404 相当）
   - 挙動
     - API 呼び出し時に 404 等のエラーを検知し、fetch はエラー終了とする
     - エラーメッセージの例
       - 「AZURE_DEVOPS_PROJECT=Kurohebi に対応するプロジェクトが見つかりません。組織名とプロジェクト名を確認してください。」
     - 必要に応じて、Azure DevOps のポータル URL など確認先をログで案内する

3. AZURE_DEVOPS_PROJECT が空文字または空白のみの場合
   - 条件
     - `.env` に `AZURE_DEVOPS_PROJECT=` だけが書かれている、または空白のみ
   - 挙動
     - 設定検証時に「未設定」と同じ扱いとして扱い、1 と同等のエラーとする

## Parameters

- コマンドライン引数
  - days（必須）
    - 過去何日分の Work Item を対象とするかを整数で指定する

- 環境変数
  - AZURE_DEVOPS_PROJECT（必須）
    - デフォルトプロジェクト名
    - fetch がプロジェクト引数なしで呼ばれた場合、必ずこの値を使用する

## Validation rules

- AZURE_DEVOPS_PROJECT が未設定または空文字の場合、fetch は必ずエラー終了しなければならない
- days 引数が不正な場合（非数値・負数など）、既存の validation ルールに従ってエラーにする
- 既存の fetch（プロジェクト引数あり）と同じ環境変数（PAT, ORG, API_VERSION, RETRY_* 等）の検証ロジックを共有し、一貫したエラー挙動とする

## Open questions

- fetch 以外のコマンド（status-history, fetch-details）が AZURE_DEVOPS_PROJECT をどう扱うかは、この capability でどこまで含めるか

