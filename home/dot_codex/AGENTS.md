# Common Rules

## Authority and execution

- 承認が必要なcommandは必要最小限かつ再利用可能な単位で早めに求める。sandbox外実行の許可を、操作内容、外部影響または権限拡張の承認とみなさない。
- deploy、release、data migrationおよびcloud resourceの変更は、ユーザーが明示的に依頼または承認した場合だけ行う。
- Sandbox内の可視性、到達性および権限と対象環境の状態を区別する。対象環境について結論する必要があれば承認された対象相当環境で最小限に観測し、確認できない範囲を明示する。
- Agent自身が作った一時resourceはownershipとcleanup対象を特定し、保持理由がなければ完了前に削除する。既存、利用者提供または対象不明の広いresourceは削除しない。

## Task interpretation

- 指示を目的、observableな成功条件、hard constraint、明示された手段および未検証の前提へ分ける。目的、authority、外部影響および受け入れ可能な結果はユーザーが決める。
- 同じscope、authority、外部影響、互換性、保存data、dependency approvalおよび主要contract内では、目的を同等以上に満たす単純で保守コストの低い内部設計を自律的に選べる。
- User-visible contract、scope、migration、dependency、権限、外部影響または確認済みの技術選択を変える必要がある場合は、根拠、影響および推奨案を示して確認する。効果が僅かな好みや根拠のない改善案のために再交渉しない。

## Data safety

- Password、private key、access/refresh token、session cookie、認証header、credential入りURLなど、所持により認証、認可、復号、署名またはなりすましが可能な値は、rawまたは復元可能な形で表示、記録またはcommitしない。
- Confidential contentとprivacy-sensitive dataはauthorizedなtask内で必要な範囲だけ扱い、無関係な外部service、public artifactまたはlogへ送らない。
- 権限不足時は、IAM管理が依頼または承認済みでない限りidentity、credential、role、policyまたはscopeを変更・拡張せず、失敗したactionとresourceを示して停止する。詳細分類とsink別規則は必要時に `~/.agents/references/data-handling.md` を読む。

## Human-facing commands

- 人間が端末へ入力するcommandは、表示用の行継続を使わず一度にcopyできる単一行にする。独立した操作は別々のcommandにする。
- 一時的な対話commandは、明示指定や環境制約がなければNushell構文を使う。Repository内のscript、task、設定およびdocument例は既存形式と対象環境を優先する。

## Dotfiles

- Homeのdotfileは原則chezmoi管理である。編集前に `chezmoi source-path <target>` を `~` または `/home/atty` のpathで確認する。
- Managed targetは適用される `AGENTS.md` を読んでsource stateを編集し、targetを直接編集しない。Unmanaged targetは自動追加せずtargetを編集する。

## Version control

- Repository操作は `$develop-repository` に従って通常のGit commandだけを使い、他VCSのmetadataを操作しない。
- Push、remote ref更新およびPR作成は、明示依頼または適用guidanceのstanding authorizationがある場合だけ行う。

## Task completion

- 全成功条件を満たす最終報告の直前だけ、runtimeに操作がありユーザーがtitleを指定・維持していなければ、thread全体の主要目的と到達点を表す簡潔なtitleへ一度更新する。途中、partial、blocked、中止またはtask置換では更新しない。
- 更新不能はtaskを妨げない。失敗時だけ試みたtitleを報告し、成功時は報告しない。

# Workflow routing

- 不具合、障害、errorまたは期待外の挙動の診断には `$investigate-problem` を使う。修正も依頼された場合は原因と観測証拠を確定してから `$develop-repository` へ引き渡す。
- Repositoryの開発、修正、refactorまたはreview対応には `$develop-repository` を使う。
- 外部境界、状態変更、async・concurrent、複数段階または再現困難なprogram経路を追加・変更する場合は、実装前に `$design-program-observability` で適用判定する。
- AGENTS、skill、agent guidance、永続化規則または過去taskの学びの保存・整理・監査をユーザーが明示的に依頼した場合だけ `$maintain-agent-guidance` を使う。通常taskの完了時には起動しない。
