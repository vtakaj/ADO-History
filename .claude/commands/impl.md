# Implement a Task

## Command Usage
`/impl [user story ID] [task ID]`
- Example: `/impl US-001 FE-001`

## Purpose
プランに基づき、指定されたタスクの実装を行う

## Important Notes
- Stop this command if no task ID is specified
- Read `./docs/plans/{user story ID}/tasks-overview.md` thoroughly
- Read `./docs/plans/{user story ID}/{user story ID}-{task ID}.md` thoroughly
- Do not use emojis in file descriptions
- Use `use context7` to reference the latest technical documentation

## Process Steps
1. **実装順の確認**: `{user story ID}-{task ID}.md` の dependency に記載されたタスクが完了していることを確認する
2. **最新の main ブランチの取得**: 最新の main ブランチのソースを取得する
3. **feature ブランチの作成**: main ブランチから feature ブランチを作成する  
   - ブランチ名: `feature/{user story ID}-{task ID}`
4. **実装**: 機能の実装を行う（`{user story ID}-{task ID}.md` の acceptance criteria を満たすこと）
5. **テストの実装**: 必要な自動テスト（ユニット・結合・E2E等）を実装・更新する
6. **lint/format**: lint / format を実行し、コード品質を担保する
7. **テスト実施**: すべてのテストがパスすることを確認する
8. **ドキュメント更新**: 必要に応じてドキュメント（README, API仕様等）を更新する
9. **コミット**: 変更をコミットする  
   - コミットメッセージ例: `feat({user story ID}-{task ID}): [変更内容の要約]`
10. **プッシュ**: feature ブランチをリモートにプッシュする
11. **Pull Request 作成**: main ブランチ向けに PR を作成する  
    - PR本文に user story ID, task ID, 変更概要、残課題・注意点を記載
    - PRテンプレート例:
      - User Story: {user story ID}
      - Task: {task ID}
      - 概要: 何を実装したか
      - 残課題・注意点: あれば記載
12. **レビュー依頼**: チームメンバーにレビューを依頼する
13. **レビュー対応**: 指摘事項があれば修正し、再度テスト・lintを実施
14. **マージ**: 承認・CI（lint, test, build など）パス後に main ブランチへマージする
15. **ステータスの更新**: `./docs/plans/{user story ID}/tasks-overview.md` の該当タスクのステータスを `done` にする

## TODOs Included in Tasks
- 依存タスクの完了確認。`./docs/plans/{user story ID}/tasks-overview.md` を参照。
- feature ブランチの作成
- 実装・テスト・lint・ドキュメント更新
- コミット・プッシュ・PR作成・レビュー・マージ
- ステータス更新（`done`）

## Output Files Structure
- 例: `src/components/ExampleComponent.tsx`
- 例: `tests/components/ExampleComponent.test.tsx`
- 例: `docs/plans/US-001/US-001-FE-001.md`
- 例: `docs/plans/US-001/tasks-overview.md`
- Pull Request: `feature/US-001-FE-001` → `main`

## Quality Criteria
- `{user story ID}-{task ID}.md` の acceptance criteria をすべて満たしていること
- lint/format チェック、テスト、CI/CD（lint, test, build など）がすべてパスしていること
- 重大なバグやリグレッションがないこと
- ドキュメントが最新であること（必要に応じて）
- 少なくとも1名以上のレビュー・承認を得ていること
