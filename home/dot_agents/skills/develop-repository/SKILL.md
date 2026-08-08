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

- 検証の目的を、利用者向けの実装結果をagent自身が観測し、期待どおりか判断できる証拠を得ることとする。人間による確認は、agentが観測できない場合の例外とする。
- formatter、lint、型検査および静的解析、対象を限定したテスト、DOM、API、ログまたは永続状態による実行時観測、ビルドおよび通常check、利用者が接する最終出力の順に、安価な検証から進める。前段の失敗を解消してから高コストな検証を行い、範囲は変更箇所と回帰リスクに比例させる。
- CLIから操作および観測できる設計を優先する。必要に応じて、application固有の設定・データパス、test profile、状態照会またはexport用のCLI・API、structured logおよびscreenshot生成を、通常動作と同じcode pathへ追加する。
- 状態を変更する検証は、temporary directory、test profile、専用database、containerまたはsimulatorなどの使い捨て可能な隔離環境で行う。実データ、通常profile、利用中の設定および実serviceを検証用に直接変更しない。隔離できず実環境での検証が必要な場合は、対象、操作、想定される状態変更および復旧方法を示して事前承認を求める。
- CLIによる検証後もGUIの表示または操作結果が未確認の場合は、[$verify-with-computer-use](../verify-with-computer-use/SKILL.md)を使用する。Computer Useが設定済みまたは利用可能だと仮定しない。
- 実行できない検証がある場合は、確認済みの範囲、未確認の結果、理由、代替検証および必要な人間確認を報告する。

### Review

- 自分の変更をローカルのcommitまたはchangeとして確定する前に、[$review](../review/SKILL.md)をすべて読み、fresh subagentによる独立レビューを完了する。
- 複数の論理単位がある場合は、変更の結合度とリスクから、タスク全体または論理単位ごとのレビューを選ぶ。
- 有効な指摘を修正して関連検証を再実行し、レビュー後に確定対象へ変更を加えた場合は、変更の種類を問わず最終diffを再レビューする。
- 独立レビューを完了できない場合は通常のblockerとして扱い、該当するcommitまたはchangeを完了扱いにしない。

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
