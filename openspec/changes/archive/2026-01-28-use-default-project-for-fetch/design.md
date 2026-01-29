## Overview

この design では、fetch コマンドからプロジェクト名の positional 引数を廃止し、`.env` の `AZURE_DEVOPS_PROJECT` を既定プロジェクトとして利用するための実装方針を定義する。

対象:
- `./ado-tracker.sh`（コマンドルーター・引数パース）
- `lib/commands/fetch.sh`（fetch コマンド本体）
- `lib/core/config_manager.sh`（設定検証ロジックの拡張）
- テストスクリプト（`tests/unit/`, `tests/integration/`）
- ドキュメント（`README.md`, `.env.template`）

## Current behavior

- fetch コマンドは、原則として次の形式で呼び出すことを想定している:
  - `./ado-tracker.sh fetch <ProjectName> <days>`
  - または、`AZURE_DEVOPS_PROJECT` を使う形と positional 引数が混在している可能性がある。
- `AZURE_DEVOPS_PROJECT` は存在するが、「あくまで一部のケースで使われる」程度で、fetch コマンドの中心的なプロジェクト決定ロジックにはなっていない。
- 設定検証（`config validate`）では、`AZURE_DEVOPS_PAT`, `AZURE_DEVOPS_ORG`, `API_VERSION`, `RETRY_*` 等の検証は行っているが、`AZURE_DEVOPS_PROJECT` は必須扱いではない。

## Target behavior

1. fetch コマンドは、次の形で呼び出す:
   - `./ado-tracker.sh fetch <days>`
   - プロジェクト名 positional 引数は受け付けず、`.env` の `AZURE_DEVOPS_PROJECT` を唯一のプロジェクト指定手段とする。

2. `AZURE_DEVOPS_PROJECT` が未設定または空文字の場合は、fetch 実行前の設定検証でエラーとし、ユーザーに `.env` の設定方法を案内する。

## CLI interface changes

- インターフェース
  - `./ado-tracker.sh fetch <days>`

- 引数の解釈
  - `fetch` サブコマンドの第 1 引数は days として扱う。
  - プロジェクト名に相当する positional 引数はサポートしない。

## Implementation plan

### 1. 引数パースの見直し（`ado-tracker.sh` / `lib/commands/fetch.sh`）

- `ado-tracker.sh` 側:
  - `case fetch)` ブロックでの引数の渡し方を確認し、`cmd_fetch` への引数が「プロジェクト名 + days」前提になっていないか確認する。
  - 今後は `cmd_fetch <days> [options...]` を基本とするように変更する。

- `lib/commands/fetch.sh` 側:
  - `cmd_fetch()` のシグネチャと内部ロジックを、`project` を positional 引数から受け取らない前提で再設計する。
  - プロジェクト決定ロジック:
    - まず環境変数 `AZURE_DEVOPS_PROJECT` を参照する。
    - ここで空または未設定の場合は、`config_manager.sh` の検証に委ねるか、明示的にエラーを返す。
  - days 引数は従来通り数値として受け取り、バリデーション（正の整数かどうか等）を行う。

### 2. 設定検証ロジックの拡張（`lib/core/config_manager.sh`）

- `validate_config()` に `AZURE_DEVOPS_PROJECT` の検証を追加する:
  - 未設定または空文字の場合:
    - エラーメッセージ: 「AZURE_DEVOPS_PROJECT が設定されていません。.env にデフォルトプロジェクトを設定してください。」
    - エラーとしてカウントし、`config validate` / `test-connection` 等と同様に非ゼロ終了とする。
  - 形式チェック（任意）:
    - 必要であれば、組織名と同様に英数字と `-` の組み合わせなどの簡易バリデーションを追加するが、Azure DevOps 側での検証に任せてもよい。

### 3. ログ出力の明示化（`lib/core/api_client.sh` / fetch コマンド）

- fetch 実行時に、使用するプロジェクト名を INFO レベルでログ出力する:
  - 例: `[INFO] プロジェクト: Kurohebi (from AZURE_DEVOPS_PROJECT)`
- エラー時にも、どの値を使おうとしたかをログに残すことで、トラブルシュートしやすくする。

### 4. テストの更新（`tests/unit/`, `tests/integration/`）

- 新規テストケース:
  - `AZURE_DEVOPS_PROJECT` が設定されている状態で `./ado-tracker.sh fetch 30` を実行した場合に、エラーなく実行されること（モック API 前提で OK）。
  - `AZURE_DEVOPS_PROJECT` が未設定の状態で `fetch 30` を実行すると、「未設定エラー」で終了すること。
  - `AZURE_DEVOPS_PROJECT` が空文字（`AZURE_DEVOPS_PROJECT=`）の場合にも未設定と同等に扱われること。

- 既存テストの見直し:
  - fetch 関連のテストで、`fetch <ProjectName> <days>` 形式を前提にしているケースがあれば、`fetch <days>` 形式に書き換える。
  - 必要であれば、「旧形式を許容する」テストは別 capability（fetch-command-cli）で扱う。

### 5. ドキュメント更新（`README.md`, `.env.template`）

- `.env.template`:
  - `AZURE_DEVOPS_PROJECT` のコメントに「fetch コマンドのデフォルトプロジェクトとして使用される」旨を明記する。

- `README.md`:
  - fetch の使用例を、原則として
    - `.env に AZURE_DEVOPS_PROJECT を設定 → fetch ではプロジェクト名を省略`
    - という流れに書き換える。
  - 旧インターフェースを残す場合は、「互換目的でサポートされているが、非推奨」であることを明記する。

## Risks and mitigations

- 既存ユーザーのコマンド履歴が `fetch <ProjectName> <days>` になっている場合、コマンドがエラーになる可能性がある:
  - README に新しい使用方法（`fetch <days>` と AZURE_DEVOPS_PROJECT の設定）を明示し、移行を促す。

- `AZURE_DEVOPS_PROJECT` の値が誤っている場合のエラーメッセージが不十分だと、原因特定が難しくなる:
  - 組織名とプロジェクト名両方の確認を促すメッセージ、および Azure DevOps ポータルの確認先をログに残すことで軽減する。

