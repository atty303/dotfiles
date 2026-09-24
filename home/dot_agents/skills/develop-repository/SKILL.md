---
name: develop-repository
description: 開発、修正、リファクタリング、レビュー対応など、リポジトリを変更するタスクで、対象リポジトリに応じた観測可能な実装、検証、ドキュメントおよび再現性の方針を適用する。
---

# Development tasks

## Frame the work

- 変更は明示されたrepository内に限定する。依頼、適用guidance、sourceおよび実環境から目的、observableな成功条件、hard constraint、明示された手段、non-goalおよび未検証の前提をclosed setとして保持する。
- 同じcontractとauthority内では、repo変更なし、削除、簡略化、既存機構、既存成果物の変更、新規成果物の順に、継続的な保守コストが低い案を選ぶ。前提崩壊により主要contractを変える必要があれば停止して確認する。
- 成果物の段階とcontrol domainは [artifact profile and control domain](../../references/artifact-profile-and-control-domain.md) で確定する。Repositoryへ残す変更は明示的なspike contractがない限り`durable`とする。
- 新規library、開発toolまたはtest packageは全repositoryで事前承認を必要とする。必要性、主要代替、保守・security・配布への影響を示し、承認前に追加も独自実装による迂回もしない。
- Repository固有の互換性方針を優先する。利用者によるmigration、data変換または選択が必要な破壊的変更は、影響と移行方法を示して実装前に確認する。

## Establish repository state

- 通常のGit commandだけを使う。Git repositoryでなければ停止し、別VCSを解釈、操作または初期化しない。
- 変更前にremoteがあればcodeと標準notes refをfetchし、branch、upstream、HEADと親、index、working tree、default branchおよび必要なdiffを確認する。Remoteにnotes refが未作成なら正常な空状態とし、network、権限、競合または破損によるfailureと区別する。Code fetch失敗時はremote情報の陳腐化を明示し、notes fetch・merge失敗時はlocalまたはremote noteを暗黙に置換しない。
- 指定branchまたは依頼に対応する既存branchを優先する。無関係な変更から新しい作業を派生させず、rewrite、既存branch移動または未確定変更を伴う切替は確認する。
- 現在のsourceやliving documentationだけでは判断できない意図、未完了範囲またはmigrationがある場合は、関連path、schema、featureまたはcommitに限定してGit logとnotesを調べる。履歴はdescriptiveであり現在の原典を上書きしない。
- 開発、build、test環境は現在のrepositoryのsource、task、build process、適用guidanceまたはユーザーの明示指定から確定する。承認済みcommand、memory、過去task、toolの存在または別用途のcontainer・runtimeだけを根拠に転用しない。

## Implement the smallest durable change

- 既存format、生成元およびrepositoryの標準taskを使う。Generated fileとlockfileはownerを特定して正規手順で更新し、推測で手編集しない。
- 補助toolの設定はupstream標準をbaselineとし、依頼に必要な最小差分だけを持つ。成果物を経緯から切り離して読み、不要なcompatibility layer、旧経路、alias、分岐、commentおよびdocumentを残さない。
- Module等の移動・分割・責務再配置では、対象の実装本体を新しい場所へ移し、内部参照も新経路へ更新する。旧経路のre-export等は確認済みの公開互換性契約に必要な場合だけ残す。実装本体を移せなければ移動完了とせず、理由と残作業を報告する。
- Program経路を追加・変更する前に `$design-program-observability` で適用判定する。対象なら [program observability contract](../../references/agent-computer-interface-observability.md) に従い、変更経路と再利用される共有境界だけを準拠させる。
- 不具合修正は先に `$investigate-problem` で原因とoracleを確定する。[failure oracle and causal verification](../../references/failure-oracle-and-causal-verification.md) に従い、既存証拠でfailure段階を識別できなければproduct fixより先に最小観測経路を作る。
- Public behavior、CLI、設定または公開APIを変えた場合は関連documentationも同じ変更で更新する。

## Verify causally

- [failure oracle and causal verification](../../references/failure-oracle-and-causal-verification.md) を完了判定に使う。Command開始だけでdownstreamの永続化や副作用を断定せず、contractが終わるboundaryをagent自身が観測する。
- Formatter、lint、型検査、対象test、runtime observation、build、標準check、最終出力の順に安価な検証から進める。`mise run check`が自動修正を示した場合は対象を限定した`mise run fix`後に再checkする。Suppression、型検査無効化またはtest skipで通さない。
- 状態を変える検証は隔離した使い捨て環境で行う。実dataまたは通常profileでしか検証できない場合は対象、変更、riskおよび復旧方法を示して承認を得る。CLI後にGUIだけ未確認なら、利用可能と仮定せず `$verify-with-computer-use` を使う。
- 必須testやoracleが予期せず失敗、timeoutまたはflakyになったら、workaroundや根拠のない再試行の前に `$investigate-problem` を使う。Repository-controlledな原因は依頼範囲内で最も近い原典を修正し、外因または未確認boundaryは証拠とともに分けて報告する。

## Decide independent review

Fresh independent reviewは次のclosed setに該当するときだけ必須とする。

- ユーザー、repositoryまたは適用skillが明示的に要求する。
- Security、secret、privacy、authority、identity、permissionまたはtrust boundaryを変更する。
- 破壊的・不可逆操作、migration、data loss、公開API・protocol・永続format・compatibilityを変更する。
- Concurrency、async、cross-process、resource lifecycle、retry、recovery、releaseまたはdeploy workflowを変更する。

Closed-set triggerは成果物種別による次の除外より優先する。Triggerに該当しない既存contract内の局所修正、documentation、単純な設定および決定的生成物は、他のguidanceが要求しない限りfresh review不要である。必須時はcommit前に [$review](../review/SKILL.md) をすべて読み、比較対象とexact diffを固定してfresh subagentまたは同等の独立agentに渡す。利用不能なら自己reviewで代替せずblockedとする。

## Commit and preserve task evidence

- Commit前に元の依頼とclosed setを読み直し、各項目を証拠、明示的な対象外または残作業へ対応付ける。Git stateとdiffを再確認し、自分の変更だけを明示的にstageして論理単位でcommitする。未確定のまま残す明示指示がなければ、完了した変更はlocal commitへ確定する。
- Commit messageはrepository慣習に従い、目的、主要理由、範囲、user-visible effect、migrationおよび主要検証を自足的に記す。慣習不明なら英語のConventional Commitsを使い、Codex co-author trailerを付ける。
- Commitを作ったtaskは [Git task evidence](../../references/git-task-evidence.md) をすべて読み、最終commitをanchorに標準noteを保存する。Codexではcomplete thread履歴の取得・照合が必須で、不能ならtaskを未完了とする。他runtimeは同等capabilityがなければskipと境界を明示できる。
- Agentが既存noteを読み、semantic conflictを解消し、分類・redaction・要約済みのnormalized bodyを作る。既存blob IDまたは`absent`を指定して `scripts/update-git-task-note.ts` を使い、schemaまたはCAS conflictでは上書きせず停止する。Helperへraw threadを渡さない。

## Remote writes and completion

- Push、remote ref更新およびPR作成は、ユーザーの明示依頼または対象refを含むrepository guidanceのstanding authorizationがある場合だけ行う。Authorizationだけでは実行を要求せず、guidanceが自動実行も指示する場合に実行する。ユーザーの明示的なno-pushまたは狭いscopeをstanding authorizationで上書きしない。PRは指定がなければready for reviewとする。
- Push前にcodeとnotesをfetchしてstateを再確認する。Codeをnon-force pushした後、local notes refがあれば別のnon-force pushで送る。Notes競合は別refへfetchして意味を保持してmergeし、解消不能ならcodeとnotesのpartial stateをblocked handoffする。Code pushをrollbackまたはforceしない。
- 成功条件とconstraintがすべて証拠付きで満たされた場合だけ完了する。未達が解消不能ならpartialまたはblockedとして、確認済み範囲、未確認結果、理由および必要な次のactionを示す。

## Repository profile

- `origin`のGitHub ownerが`atty303`なら [atty303 engineering policy](references/atty303-engineering-policy.md) を読む。Owner不明時は配置と依頼から推定し、適用規則を変える不明点だけ確認する。
- Other repositoryではその方針を優先し、`atty303` profileのImplementation Style、Comments、Testing Strategyだけを設計選好として使う。依頼に不要な`mise`、CIその他の基盤は導入しない。
