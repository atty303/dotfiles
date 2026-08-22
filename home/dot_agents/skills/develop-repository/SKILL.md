---
name: develop-repository
description: 開発、修正、リファクタリング、レビュー対応など、リポジトリを変更するタスクで、対象リポジトリに応じた観測可能な実装、検証、ドキュメントおよび再現性の方針を適用する。
---

# Development Tasks

## Common

- 明示的な指示がない限り、開発タスクによる変更は対象リポジトリ内に限定する。
- `origin` がない、またはGitHub ownerを判定できない場合は、配置、作成目的および依頼の文脈から
  `atty303` またはOtherを推定する。適用規則に影響する不明点が残る場合だけ確認を求める。

### Artifact Profile and Control Domain

- 変更前に、成果物を`spike`または`durable`へ分類する。`spike`は仮説検証用で、そのままrelease、常用、再利用または運用依存されない成果物とする。`durable`はそれらのいずれかを想定する成果物とする。一時領域だけで完結して残さない検証コードは`spike`と判断できるが、repositoryへ残す変更は依頼、計画またはrepositoryの原典で非本番の仮説、終了条件およびpromotion条件を確認できない限り`durable`とする。既存のdurableな経路を実装都合で`spike`へ降格しない。
- 既定のtrusted control domainを、同一利用者が所有・管理するpersonal computing environment全体とする。明示的な相互不信またはisolation contractがない限り、そのmachine上のaccount、UID、root、process、service、filesystem、local IPC、containerおよびVMを同じdomainに含め、分離単位だけを理由に敵対者を仮定しない。
- 外部主体が制御するnetwork endpointとの入出力、成果物が入力または未検証payloadとして受け入れる外部主体が内容を制御するdataまたは実行code、他人、別organizationまたは外部serviceが所有するaccount、credentialまたはresource、明示されたmulti-tenant環境または相互不信、保証対象であるsandbox、account、containerまたはVM間のisolation、および配布・運用主体の変更で新しく加わる外部主体をtrust boundaryとする。これらのdataとcodeはlocalへ保存した後もcontrol provenanceを維持する。正規の採用手順で固定・検証され、trusted domainのcomponentとして扱うdependencyまたはtoolは、外部由来であることだけではdomain外主体とみなさない。loopbackまたはlocal IPCは、それ自体で境界とせず、control domain外から到達する場合だけ境界とする。
- Trust boundaryとoperational safetyを分ける。同一利用者のrootと一般UIDを敵対者関係とはみなさないが、authority、irreversibilityおよびblast radiusが増す操作は、誤削除、system破損、data lossおよび復旧可能性の観点で確認する。誤入力、partial write、crash、timeout、並行実行およびcleanup失敗は、攻撃ではなく到達可能なcorrectnessまたはreliabilityとして扱う。trustedな利用者による自身の設定や状態の意図的改変は、明示的なintegrity contractがない限り防御しない。Secretは値が与える認証、認可、復号、署名またはなりすまし能力、confidential contentは明示的な非公開contractで識別し、control domain外への送信、記録または共有を防ぐ。Operational identifierの存在だけを漏洩とみなさない。
- `spike`では、仮説を判定できること、意図しないdata loss、control domain外へのsecretまたは明示的なconfidential contentの漏洩、現在の出力contractに含まれるpublicまたは無関係な外部sinkへの不要なprivacy-sensitive dataおよび個人・host固有operational identifierの送信・公開、authority逸脱を防ぐこと、および作成した一時resourceをcleanupできることだけを完了条件とする。trust boundary外との入出力が仮説に含まれる場合だけその経路を確認し、本番化しなければ価値のないhardeningを実装しない。検証済みの本番化懸念は重複排除し、該当する既存のplan、statusその他のrepository原典があればそこへ、なければ最終handoffの短いpromotion checklistへ集約する。Checklistだけを保存する新しいrepository成果物は作らない。
- `spike`を`durable`へ昇格するときは、残す成果物全体についてcontrol domain、外部由来入力、外部resourceおよび保護対象を再確定し、spike時の確認をreview済みとみなさず、durableな成果物として検証とfresh reviewを行う。

### Repository State

- 開発タスクの開始時は、変更前に `<develop-repository-dir>/scripts/vcs.sh snapshot --fetch [REMOTE]` を実行する。リポジトリを変更しない調査、説明および外部serviceの参照だけなら実行しない。
- VCS判定、fetch、working state、current commitと親、作業線、追跡先、default lineおよびdiff範囲はsnapshot出力をSSOTとし、個別の`git`または`jj` commandで同じ状態を再構成しない。`jj` repoではworking-copy commit、bookmarkおよびtracked remote bookmarkを判断根拠とし、colocated Gitのbranchやdetached HEADを使用しない。
- `fetch_status=failed`ならローカルsnapshotは利用できるが参照情報が古い可能性を明示して作業可否を判断する。`workspace_status=stale`なら自動修復せず、影響を確認してから`jj workspace update-stale`の実行可否を決める。
- ユーザーが指定した作業線、依頼に対応する既存branch、bookmarkまたは未完了changeがある場合は、その継続を優先する。新しい独立した変更では、repoの運用規約、未統合変更、依頼との関連性およびPR作成要否から、default branch上で直接作業するか、最新のremote default branchを起点にbranch、bookmarkまたはchangeを作るかを判断する。現在の作業線に無関係な変更がある場合は、そこから新しい変更を派生させない。
- 意図しない作業開始点、古いdefault branch、依頼と無関係なbranchまたはbookmarkなどを検出した場合は、ユーザー変更と公開済み履歴を保持したまま作業開始点を適正化する。scriptはbranch作成、rebase、workspace更新またはbookmark移動を行わない。履歴のrewrite、既存branchまたはbookmarkの移動、未確定変更を伴う切替が必要なら、影響を示して事前確認を求める。
- commitまたはchangeの確定前に同scriptの `snapshot` を再実行し、working copyまたはcurrent changeの親、branchまたはbookmarkの位置、diffの範囲および既存のユーザー変更との分離が、開始時に選択した作業線と一致することを確認する。長時間の作業やremote default lineの更新が統合判断に影響する場合は `snapshot --fetch [REMOTE]` を使う。default lineが進んだことだけを理由に自動でmerge、rebase、rewriteまたはbookmark移動を行わない。
- 確定対象を確認後、同scriptの `commit -m MESSAGE -- PATH...` で自分の変更だけを確定する。current change全体が対象であると確認済みの場合だけ `--all` を使う。scriptがGitのstageとcommitまたは`jj commit`を選択し、Codexのco-author trailerを付ける。
- 明示的にpushを依頼された場合だけ、通常権限で `vcs.sh snapshot --fetch REMOTE` を実行して結果を確認した後、`<develop-repository-dir>/scripts/vcs-push.sh REMOTE BRANCH_OR_BOOKMARK` をsandbox外で実行し、その実行ごとに承認を求める。push scriptの再利用可能な承認prefixは要求しない。`jj`でchange bookmarkを生成する場合は第2引数以降を `--change REVISION` とする。

### Change Cost

- コード、設定、テスト、文書、コメント、互換処理およびcommitを、すべて継続的な保守コストとして扱う。変更前に、現在の要求をrepo変更なしの操作、既存成果物の削除・簡略化、または既存機構の利用では達成できないことを確認する。
- 要求された永続性、再現性および配置を含む同じ範囲の正しさを得られる場合は、永続成果物なし、削除・簡略化、既存成果物の変更、新規成果物の順に優先する。自動化、宣言性、網羅性または新機能の利用だけを追加理由にしない。
- 一時的な環境状態、原因または反証により恒久的な再発経路がないと確認した失敗経路および未確認の将来要件を、恒久的なコード、移行処理、テスト、コメントまたは文書へ変換しない。
- commit前に、最終成果物をdiffや実装経緯から切り離して確認する。追加・変更が現在の具体的要件に必要で、同じ正しさを得るより保守コストの低い代替がないことを説明できない場合は、不要な追加を削除し、不要な変更を取り消す。永続変更が残らなければcommitしない。

### Problem Fixes

- 不具合、障害、回帰または期待と異なる挙動を修正する場合は、product codeを変更する前に
  `investigate-problem` を使用する。利用者が失敗と判断した最終状態、保持済みdiagnostic run、failure oracleおよび原因を
  確認してから修正へ進む。
- 既存の観測証拠ではfailure段階を識別できず、対象経路がprogram観測契約の適用対象なら、product fixより先に
  `design-program-observability` で最小の観測経路を実装し、同じfailureを取得できることを確認する。既存証拠で十分なら
  不要なinstrumentationを追加しない。

### Program Observability

- program経路を追加または変更する前に、[$design-program-observability](../design-program-observability/SKILL.md)を使用して
  適用判定を行う。適用対象では、結果面、操作面およびout-of-bandな観測面を最初の実装から分離し、診断情報をpublicな
  stdout、stderr、API responseまたはUIへ後付けしない。
- 既存programでは、今回変更する経路とそこから再利用される共有境界を準拠させる。依頼がない限り、変更経路外のprogram
  全体を観測契約へ移行しない。

### Generated Artifacts

- 自動生成fileとlockfileは手動編集せず、生成元または採用済みpackage managerを変更し、repositoryで定義された手順で更新する。ownerまたは生成手順を特定できない場合は、推測で編集せず停止する。

### Verification

- 検証の目的を、利用者向けの実装結果について、断定する結果が成立するboundaryをagent自身が観測し、期待どおりか判断できる証拠を得ることとする。requestやcommandの開始だけを観測してdownstreamの永続化や副作用の成功を断定しない。契約がrequest発行またはcommand開始までなら、そのboundaryの観測を完了証拠とし、不要なdownstream readbackを要求しない。人間による確認は、agentが観測できない場合の例外とする。
- formatter、lint、型検査および静的解析、対象を限定したテスト、DOM、API、ログまたは永続状態による実行時観測、ビルドおよび通常check、利用者が接する最終出力の順に、安価な検証から進める。前段の失敗を解消してから高コストな検証を行い、範囲は変更箇所と回帰リスクに比例させる。
- `mise run check` で自動修正可能なformatterまたはlint違反が判明した場合は、表示された修正diffの精査や手動編集より、対象を限定した `mise run fix` を優先し、その後にcheckを再実行する。
- 検証を通すことだけを目的にlint suppressionを追加・変更せず、型検査を無効化せず、testをskipしない。要件上必要な例外は理由、影響および代替検証を示して承認を得る。既存の正当な例外を依頼と無関係に除去しない。
- 検証が予期せず失敗、停止またはtimeoutした場合は、入力変更、代替経路または再試行を重ねる前に
  `investigate-problem` を使用する。観測面が不足している場合は、`design-program-observability` へ引き渡してから元の開発へ戻る。
- 原因をsource、test harness、taskまたはbuild process、実行環境、一時的外因のいずれかへ分類する。依頼範囲内にある決定的な再発経路は最も近い原典で除去し、その修正を検証してから元の開発と検証を再開する。依頼範囲内の原典で解消できない横断的問題、未確定または非決定的な問題だけを最終報告時の永続化評価へ残し、一時的外因は永続化候補にしない。
- CI、外部service、container、権限または複数runtimeの境界をまたぐ広範な変更では、全面実装前に代表的な1経路のvertical spikeを実装し、各境界を実環境相当で検証する。spikeが成功してから同じ設計を残りの対象へ展開する。
- CLIまたはAPIから操作と状態照会を行える設計を優先する。診断証拠はprogram観測契約に従うout-of-bandな観測面または
  artifactから取得し、publicな結果面をagent向けdiagnostic transportとして歪めない。
- 状態を変更する検証は、temporary directory、test profile、専用database、containerまたはsimulatorなどの使い捨て可能な隔離環境で行う。実データ、通常profile、利用中の設定および実serviceを検証用に直接変更しない。隔離できず実環境での検証が必要な場合は、対象、操作、想定される状態変更および復旧方法を示して事前承認を求める。
- CLIによる検証後もGUIの表示または操作結果が未確認の場合は、[$verify-with-computer-use](../verify-with-computer-use/SKILL.md)を使用する。Computer Useが設定済みまたは利用可能だと仮定しない。
- 実行できない検証がある場合は、確認済みの範囲、未確認の結果、理由、代替検証および必要な人間確認を報告する。

### Review

- `durable`な変更をローカルのcommitまたはchangeとして確定する前に、[$review](../review/SKILL.md)をすべて読み、成果物が実際に越えるtrust boundaryとoperational safety上のblast radiusに比例したfresh subagent reviewを完了する。`spike`は独立レビューを必須とせず、上記の目的限定の完了条件を実装者が確認する。明示的にspikeのreviewを依頼された場合は、`review`へartifact profileと目的限定のacceptance criteriaを渡す。
- 複数の論理単位がある場合は、変更の結合度とリスクから、タスク全体または論理単位ごとのレビューを選ぶ。
- 指摘を`review`が定める基準で自動対応、棄却またはユーザー判断へ裁定する。自動対応とユーザーが採用した対応対象だけを一括修正して関連検証を再実行し、比例的な再確認と最終diffの完了条件を満たす。
- 必須となる独立レビューを完了できない場合は通常のblockerとして扱い、該当するdurableなcommitまたはchangeを完了扱いにしない。

### Compatibility and Documentation

- 対象リポジトリ固有の互換性方針を優先した上で、タスク達成に必要な破壊的変更は許容する。利用者による移行または選択が必要な場合は、実装前に確認を求める。
- 利用者向けの挙動、CLI、設定または公開APIを変更した場合は、関連するドキュメントも更新する。

### Final Report

- 最終報告の前に、[$maintain-agent-guidance](../maintain-agent-guidance/SKILL.md)をすべて読み、タスク中の具体的な失敗、確認、成功およびprocess上の問題から永続化候補を評価する。
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
