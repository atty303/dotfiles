---
name: review
description: branch、pull request、commit、patchまたはworking treeのdurableなコード変更を、成果物段階とcontrol domainに比例させ、実装者の推論や会話履歴を引き継がないfresh subagentで独立レビューする。レビュー依頼時、およびdurableな変更をローカルcommitまたはchangeとして確定する前に使用する。
---

# 独立コードレビュー

Durableな変更または明示的にレビューを依頼された変更について、実装者自身の自己レビューではなく、最低1体のfresh subagentによる独立レビューを行う。レビューだけを依頼された場合は、明示的に修正も依頼されない限りファイルを変更しない。非本番の仮説検証として確定した`spike`はcommit前reviewの必須対象にせず、明示的にreviewする場合も仮説とoperational safetyに指摘範囲を限定する。

## レビュー候補を固定する

- 元の要求、artifact profile、acceptance criteria、比較対象、変更ファイルおよび実行済み検証を確認する。
- `develop-repository`に従い、trusted control domain、外部由来のdataまたはcode、外部resource、保護対象、および今回実際に越えるtrust boundaryを固定する。明示がなくてもsourceと運用形態から一意に導出できる場合は補い、review結果を変える不明点だけを確認する。
- 適用される `AGENTS.md` とリポジトリ固有の原典を特定する。
- main agentが作成した変更と既存のユーザー変更を区別し、レビュー対象を明示する。
- 複数の論理commitまたはchangeがある場合は、変更の結合度とリスクから、タスク全体または論理単位ごとのどちらでレビューするか判断する。
- formatter check、lint、型検査および軽量testを先に成功させ、比較対象とexact diffをレビュー候補snapshotとして記録する。初回reviewerの最終報告と並行検証結果を収集するまで対象diffを変更しない。
- snapshotを固定したらreviewerを直ちに起動し、integration、E2Eおよびbuildなどの重い検証を同じsnapshotに対して並行実行する。重い検証の完了をreviewer起動前の条件にしない。

## Fresh reviewerを起動する

- 最低1体の読み取り専用subagentを、実装時の会話履歴を継承しないfresh threadとして起動する。履歴の継承範囲を指定できる場合は継承なしを選ぶ。
- reviewerには次の原材料だけを渡す。
  - 元のユーザー要求または中立なacceptance criteria
  - `spike`または`durable`のartifact profile
  - trusted control domain、外部由来のdataまたはcode、外部resource、保護対象および実際に越えるtrust boundary
  - working directory、比較対象およびレビュー範囲
  - 適用される規約の所在
  - 現在のsource、exact diff、完了済みの生の検証結果および並行実行中か未実行の検証
- 実装計画、採用した設計の正当化、途中の推論、疑わしい箇所、main agentの自己レビューおよび期待する指摘は渡さない。
- reviewerにはterminal reviewerとして自分でレビューを完了し、subagentへ再委譲しないよう指示する。このSkill自体の使用を要求せず、独立レビューの担当範囲と出力契約を直接渡す。
- reviewerには1 turn内でレビュー範囲全体の調査、候補の検証および重複排除を完了し、全指摘を1つの最終報告に集約させる。途中経過ではactionableな指摘や未確定の候補を送らせない。
- 変更の規模、境界およびリスクに応じて、追加reviewerの人数、観点、モデル、reasoning effortおよび並列性を判断する。小規模かつ低リスクな差分は1体・既定effortを基本とし、high以上のeffortや追加reviewerはsecurity、並行処理、resource lifecycle、migrationまたは複数境界へ及ぶ複雑な差分など、高リスクな変更に限定する。固定の観点や人数は設けない。

## 指摘を収集する

reviewerには、日本語でactionableな指摘だけを返させる。各指摘に次を含める。

- 重大度
- ファイルと行
- 影響を受ける挙動
- 到達可能な失敗条件
- どの主体がどのdata、codeまたはresourceを制御し、どのtrust boundaryを越えるか。security issueでなければ、代わりに成立するcorrectness、reliabilityまたはoperational safety上の条件
- コードまたは検証結果に基づく根拠
- 最小限の修正方針

型または静的検査で既に排除される問題、根拠のない推測、単なるスタイル上の好みは除外させる。候補は、artifact profileで保証する明示的なcontract、invariant、security policyまたは適用されるcompatibility requirementへの違反、あるいは確定したcontrol domainとtrust boundaryから到達可能な現在のcorrectness、security、reliability、operational safetyまたはdata integrity上の欠陥に限定する。重要な指摘がない場合は、その旨と未確認の残存リスクを明示させる。

同一利用者が所有・管理するpersonal computing environmentでは、明示的な相互不信またはisolation contractがない限り、別account、UID、root、process、service、filesystem、local IPC、container、VMまたは書換可能なlocal fileであることだけを攻撃経路にしない。成果物が入力または未検証payloadとして受け入れる、外部主体が内容を制御するdataまたは実行codeはlocalへ保存された後も外部controlとして扱うが、正規の採用手順で固定・検証されtrusted domainのcomponentとして扱うdependencyまたはtoolは、外部由来であることだけではdomain外主体とみなさない。loopbackまたはlocal IPCはcontrol domain外から到達する場合だけtrust boundaryとする。権限差、破壊的操作、partial write、crash、timeout、並行実行またはcleanupは、敵対者を仮定せず、現実的な事故のblast radiusと回復可能性から評価する。

`spike`では、仮説判定を妨げる欠陥、意図しないdata loss、control domain外への秘密または保護dataの漏洩、authority逸脱、および一時resourceのcleanup不良だけをactionableな指摘とする。耐敵対入力、長期運用、互換性、可用性または包括的validationなど、本番化しなければ価値のないhardeningは現在の欠陥にせず、具体的な到達経路を検証できたものだけを重複排除したpromotion checklist候補とする。

外部process、一時resource、streamまたはintegration boundaryを変更する場合は、callerとhelper、clientとserverなど境界の両側について、dataとcontrol flow、stdoutとstderr、exit statusまたはexception、failure、timeout、signal、cleanup ownershipおよび残留状態を追跡させる。同じversion、process、classloader、environmentまたはlifecycleを共有すると仮定しない。resource取得前にcleanupが有効になること、完了状態がatomicに公開されること、およびcleanup失敗を成功扱いしないことも確認させる。

## 指摘を検証して裁定する

- subagentの指摘を未検証の候補として扱い、参照箇所、実行経路、型、validation、テストおよび不変条件をmain agent自身で確認する。
- reviewerの最終報告を受け取るまで、そのレビューに基づく修正を開始しない。
- reviewと並行検証の結果をすべて収集してから、検証済みの指摘を次の4種類へ裁定する。
  - 自動対応: 現在の要求、acceptance criteriaまたは既存方針から期待結果が一意に決まる違反、再現可能なcorrectness、securityまたはdata
    integrity上の欠陥、および検証失敗のうち、元の依頼範囲内で局所的に修正でき、新しい依存、権限またはmigrationを必要としないもの。
  - 棄却: 誤検出、重複、到達不能、型または既存validationで排除済み、根拠のない将来懸念、単なるstyle選好、および現在の要求外のgeneralization。
  - ユーザー判断: 現在の要求、acceptance criteriaおよび既存方針だけでは公開挙動、API、設計、scopeまたは継続的な保守コストが一意に決まらないもの、新しい依存、権限またはmigrationを伴うもの、および元の依頼から権限を拡大するもの。
  - Promotion条件: `spike`の仮説またはoperational safetyには影響せず、`durable`へ昇格するときだけ成立する検証済みの懸念。現在は修正せず、該当する既存のplan、statusその他のrepository原典があればそこへ、なければ最終handoffの短いpromotion checklistへ重複排除して集約する。Checklistだけを保存する新しいrepository成果物は作らず、reviewだけの依頼ではfileを変更せずreview結果として報告する。
- 到達可能な現在の欠陥がなく、採用済みのarchitecture、policyまたはtradeoffに対する別案、あるいは要求外の任意改善にすぎない指摘は棄却する。欠陥があり、要求または既存方針から結果が一意に決まる場合は、公開挙動または内部設計に触れても自動対応とする。複数の妥当な選択肢または新しい権限が残る場合だけユーザー判断とする。
- 自動対応に分類した指摘と、ユーザーが採用して対応対象へ移した指摘だけを一括修正する。重大度の高さだけを理由に、ユーザー判断に分類される設計またはscopeを自動決定しない。
- ユーザー判断が必要な指摘は、すべての結果を収集した後に一度だけ、根拠、利用者への影響、変更規模および推奨する採否をまとめて提示する。該当指摘がなければ確認turnを挟まない。
- ユーザーの回答後、採用された案を回答で指定された範囲に限って対応対象へ移し、採用されなかった案を棄却として確定する。
- 棄却した指摘は個別にユーザーへ列挙しない。タスクの理解に必要な場合だけ、最終報告で件数と代表的な棄却理由を要約する。
- Promotion条件は現在の修正またはユーザー判断の対象へ移さない。昇格が依頼されたときにcontrol domainと成果物全体を再確認し、durableな変更に対するfresh reviewで採否を判定する。
- ユーザー判断を待つ間も、判断対象と独立した検証および自動対応は継続する。判断対象そのものは修正しない。レビューへの返信またはreview threadのresolveは、修正方針への同意とは別の外部書き込みとして、明示的に依頼された場合だけ行う。
- 修正後に安価な検証を再実行し、同じ比較対象に対する新しいexact diffを固定する。修正で観測対象または入力が変わった重い検証だけを無効とし、再確認と並行して再実行する。

## 修正後の差分を再確認する

- 修正が書式、import整理、文言または決定的な生成結果だけで、直接検査により元指摘の解消とdelta全体を確認でき、executable behavior、不変条件および公開interfaceを変えない場合は、初回独立レビューと関連検証を完了条件に使用し、delta reviewを省略できる。
- 次をすべて満たす場合は、最初の独立性を維持したまま元reviewerへdelta reviewを依頼する。
  - 変更が受理した指摘または検証失敗への対応だけである。
  - 元の要求、設計境界、不変条件および公開interfaceを変えない。
  - schema、依存、権限またはsecurity、workflowまたはrelease、並行処理、resource lifecycleおよびmigrationへ影響しない。
- delta reviewerには元の指摘、修正前後のsnapshot、deltaおよび生の検証結果を渡し、指摘の解消とdeltaから到達可能な新しい問題だけを確認させる。
- 条件を一つでも満たさない修正、systemicな指摘、または元reviewerが利用できない場合は、別のfresh subagentへ最終diff全体のreviewを依頼する。
- 複数reviewerを並行起動した場合は、修正の影響を受ける元reviewerだけにdelta reviewを依頼する。観点をまたぐ変更はfresh full reviewへ戻す。
- delta reviewまたはfresh full reviewと、無効になった重い検証を同じsnapshotに対して並行実行する。対象diffが実行中に変わった場合、そのreviewと検証結果を完了判定へ使用しない。
- 重要な指摘が残らず、必要な検証が成功し、review済みのexact diff、または初回review済みexact diffへ上記の省略条件を満たす直接確認済みexact deltaだけを適用したdiffと、確定対象が一致した時点でreviewを完了する。
- subagentを起動できない、レビューが完了しない、または完了に必要なユーザー判断や追加権限を得られない場合は通常のblockerとして扱い、自己レビューで代替しない。
