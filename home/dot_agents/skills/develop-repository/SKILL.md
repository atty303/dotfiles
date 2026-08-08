---
name: develop-repository
description: 開発、修正、リファクタリング、レビュー対応など、リポジトリを変更するタスクで、対象リポジトリに応じた実装、検証、ドキュメントおよび再現性の方針を適用する。
---

# Development Tasks

## Common

- 明示的な指示がない限り、開発タスクによる変更は対象リポジトリ内に限定する。
- `origin` がない、またはGitHub ownerを判定できない場合は、配置、作成目的および依頼の文脈から
  `atty303` またはOtherを推定する。適用規則に影響する不明点が残る場合だけ確認を求める。

### Verification

- 変更後は、関連するテスト、lint、型検査およびビルドを実行する。
- 実行できない検証がある場合は、未実行の項目と理由を報告する。

### Compatibility and Documentation

- 対象リポジトリ固有の互換性方針を優先した上で、タスク達成に必要な破壊的変更は許容する。利用者による移行または選択が必要な場合は、実装前に確認を求める。
- 利用者向けの挙動、CLI、設定または公開APIを変更した場合は、関連するドキュメントも更新する。

### Final Report

- 変更概要、実行した検証、未実行または未解決の項目を簡潔に報告する。

## `atty303` Repositories

- `origin` のGitHub ownerが `atty303` の場合に適用する。
- [atty303 Engineering Policy](references/atty303-engineering-policy.md)をすべて読み、対象リポジトリ固有の方針を優先して適用する。

## Other Repositories

- `origin` のGitHub ownerが `atty303` でない場合に適用する。
- 対象リポジトリの方針を優先する。方針がない部分では、`atty303` RepositoriesのImplementation
  Style、CommentsおよびTesting Strategyだけを設計選好として考慮する。
- 依頼達成に必要な場合を除き、`atty303` 方針への適合だけを目的とする `mise`
  設定、CIまたはその他の開発基盤を導入しない。
