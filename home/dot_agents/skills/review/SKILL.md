---
name: review
description: branch、pull request、commit、patchまたはworking treeのコード変更を、実装者の推論や会話履歴を引き継がないfresh subagentで独立レビューする。レビュー依頼時、およびリポジトリ変更をローカルcommitまたはchangeとして確定する前に使用する。
---

# 独立コードレビュー

実装者自身の自己レビューではなく、最低1体のfresh subagentによる独立レビューを行う。レビューだけを依頼された場合は、明示的に修正も依頼されない限りファイルを変更しない。

## レビュー候補を固定する

- 元の要求、acceptance criteria、比較対象、変更ファイルおよび実行済み検証を確認する。
- 適用される `AGENTS.md` とリポジトリ固有の原典を特定する。
- main agentが作成した変更と既存のユーザー変更を区別し、レビュー対象を明示する。
- 複数の論理commitまたはchangeがある場合は、変更の結合度とリスクから、タスク全体または論理単位ごとのどちらでレビューするか判断する。
- formatter check、lint、型検査および軽量testを先に成功させ、比較対象とexact diffをレビュー候補snapshotとして記録する。初回reviewerの最終報告と並行検証結果を収集するまで対象diffを変更しない。
- integration、E2Eおよびbuildなどの重い検証は、同じsnapshotに対するfresh reviewと並行して実行する。重い検証の完了をreviewer起動前の条件にしない。

## Fresh reviewerを起動する

- 最低1体の読み取り専用subagentを、実装時の会話履歴を継承しないfresh threadとして起動する。履歴の継承範囲を指定できる場合は継承なしを選ぶ。
- reviewerには次の原材料だけを渡す。
  - 元のユーザー要求または中立なacceptance criteria
  - working directory、比較対象およびレビュー範囲
  - 適用される規約の所在
  - 現在のsource、exact diff、完了済みの生の検証結果および並行実行中か未実行の検証
- 実装計画、採用した設計の正当化、途中の推論、疑わしい箇所、main agentの自己レビューおよび期待する指摘は渡さない。
- reviewerにはterminal reviewerとして自分でレビューを完了し、subagentへ再委譲しないよう指示する。このSkill自体の使用を要求せず、独立レビューの担当範囲と出力契約を直接渡す。
- reviewerには1 turn内でレビュー範囲全体の調査、候補の検証および重複排除を完了し、全指摘を1つの最終報告に集約させる。途中経過ではactionableな指摘や未確定の候補を送らせない。
- 変更の規模、境界およびリスクに応じて、追加reviewerの人数、観点、モデル、reasoning effortおよび並列性を判断する。固定の観点や人数は設けない。

## 指摘を収集する

reviewerには、日本語でactionableな指摘だけを返させる。各指摘に次を含める。

- 重大度
- ファイルと行
- 影響を受ける挙動
- 到達可能な失敗条件
- コードまたは検証結果に基づく根拠
- 最小限の修正方針

型または静的検査で既に排除される問題、根拠のない推測、単なるスタイル上の好みは除外させる。重要な指摘がない場合は、その旨と未確認の残存リスクを明示させる。

外部processまたは一時resourceのlifecycleを変更する場合は、正常系だけでなくfailure、timeoutおよびsignalの各終了経路を追跡させる。resource取得前にcleanupが有効になること、完了状態がatomicに公開されること、cleanup失敗を成功扱いしないこと、および終了後に残留状態がないことを確認させる。

## 指摘を検証して一括修正する

- subagentの指摘を未検証の候補として扱い、参照箇所、実行経路、型、validation、テストおよび不変条件をmain agent自身で確認する。
- reviewerの最終報告を受け取るまで、そのレビューに基づく修正を開始しない。
- 誤検出と重複を除き、reviewと並行検証の結果をすべて収集してから、タスク範囲内の有効な指摘と失敗を一括修正する。
- 修正後に安価な検証を再実行し、同じ比較対象に対する新しいexact diffを固定する。修正で観測対象または入力が変わった重い検証だけを無効とし、再確認と並行して再実行する。

## 修正後の差分を再確認する

- 次をすべて満たす場合は、最初の独立性を維持したまま元reviewerへdelta reviewを依頼する。
  - 変更が受理した指摘または検証失敗への対応だけである。
  - 元の要求、設計境界、不変条件および公開interfaceを変えない。
  - schema、依存、権限またはsecurity、workflowまたはrelease、並行処理、resource lifecycleおよびmigrationへ影響しない。
- delta reviewerには元の指摘、修正前後のsnapshot、deltaおよび生の検証結果を渡し、指摘の解消とdeltaから到達可能な新しい問題だけを確認させる。
- 条件を一つでも満たさない修正、systemicな指摘、または元reviewerが利用できない場合は、別のfresh subagentへ最終diff全体のreviewを依頼する。
- 複数reviewerを並行起動した場合は、修正の影響を受ける元reviewerだけにdelta reviewを依頼する。観点をまたぐ変更はfresh full reviewへ戻す。
- delta reviewまたはfresh full reviewと、無効になった重い検証を同じsnapshotに対して並行実行する。対象diffが実行中に変わった場合、そのreviewと検証結果を完了判定へ使用しない。
- 重要な指摘が残らず、必要な検証が成功し、review済みのexact diffと確定対象が一致した時点でreviewを完了する。
- subagentを起動できない、レビューが完了しない、または修正にユーザー判断や追加権限が必要な場合は通常のblockerとして扱い、自己レビューで代替しない。
