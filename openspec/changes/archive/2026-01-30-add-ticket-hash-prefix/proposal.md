## Why

作業記録テーブルのチケット番号が数字のみで表示されており、他の出力と形式が揃わず判別しにくい。月次の作業記録を読みやすくするため、表と一覧の表示形式を統一したい。

## What Changes

- generate-work-table の出力でチケット番号の先頭に # を付与する
- 作業記録テーブルと対応チケット一覧の表示形式を統一する

## Capabilities

### New Capabilities
- work-table-ticket-hash-prefix: 作業記録テーブルとチケット一覧でチケット番号に # を付与して表示する

### Modified Capabilities
- なし

## Impact

- lib/formatters/markdown.sh の出力形式
- generate-work-table の出力ファイル内容
- 関連するテストとドキュメント
