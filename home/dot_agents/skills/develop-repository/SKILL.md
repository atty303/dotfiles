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
- Branchの作成・切り替えを判断する前にRepository profileを適用する。適用されるbranch方針がなければ、指定branchまたは依頼に対応する既存branchを優先する。無関係な変更から新しい作業を派生させず、rewrite、既存branch移動または未確定変更を伴う切替は確認する。
- 現在のsourceやliving documentationだけでは判断できない意図、未完了範囲またはmigrationがある場合は、関連path、schema、featureまたはcommitに限定してGit logとnotesを調べる。履歴はdescriptiveであり現在の原典を上書きしない。
- 開発、build、test環境は現在のrepositoryのsource、task、build process、適用guidanceまたはユーザーの明示指定から確定する。承認済みcommand、memory、過去task、toolの存在または別用途のcontainer・runtimeだけを根拠に転用しない。
- 変更taskの開始時にrelease workflowの参照を軽く確認する。`uses: atty303/repository-template/.github/actions/release@...` とsemantic-releaseの直接実行・action参照を対象とし、前者は`versioning`入力で`semver`か`calver`かを分ける。通常はworkflowの稼働状況やrelease実装の内部を追わない。

## Agree on commit release impact

- 上記のrelease workflowを使うrepositoryではConventional Commitsを必須とする。Repository固有のtype、scope、文体など両立する慣習にも従い、release判定と矛盾する慣習があればcommit前に確認する。その他のrepositoryではConventional Commitsを推奨し、明示されたrepository慣習を優先する。
- 対象repositoryではrelease workflowを確認した直後、他の調査・実装へ進む前の利用者向け応答で、このtaskで作るcommit全体のrelease要否を提案・送信して承認を求める。SemVerなら最大bump（`major`/`minor`/`patch`/`none`）も、`versioning: calver`のactionならrelease要否だけを提案する。利用可能なら非同期の質問手段を使い、回答を待たずに承認済みの作業を進める。詳細が未確定でも現在の情報による暫定提案と不確実性を先に送り、判明後に変更が必要なら速やかに再提案する。既に利用者が明示した判断は再確認しない。複数commitのtype、scope、件数は承認範囲内で決める。既存の未リリースcommitが次回release全体に与える影響と、このtaskの上限は区別する。
- 現行の標準判定は、`feat`→minor、`fix`・`perf`・`revert`→patch、`docs`・`test`・`ci`・`build`・`chore`・通常の`refactor`→releaseなし、認識された`!`またはfooterの`BREAKING CHANGE:`→majorとする。通常taskでこの表を調べ直さない。判明しているrepository固有の`releaseRules`、preset、parser設定は優先する。`repository-template` actionは`revert:`と`!`を認識するが、semantic-releaseの直接利用では既定parserが`revert:`や`!`だけをrelease要因として認識するとは限らない。直接利用でそれらを使う場合は設定を確認し、必要なreleaseが確実に起きる記法を選ぶ。
- 現在の基準releaseが0.xなら、破壊的変更だけを理由にmajor記法を付けない。破壊的な`fix`も`fix`のままpatch、`feat`はminorとし、変更の実態と異なるtypeでbumpを調整しない。1.xへの移行は利用者の明示的な指示・承認がある場合だけ許す。0.xの基準releaseを確認できずrelease影響を確定できない場合は、そのcommitを保留する。
- 開始時の提案を送った後は回答待ちでも、commitなしで実施できる承認済みの実装、文書、検証、reviewなどをすべて進める。Releaseが必要なら少なくとも一つのcommitでreleaseを起こし、必要な修正を`chore`として抑えない。完成した変更が承認されたrelease要否・上限と合わなければ、残る作業を進めたうえで差を示し、commitを保留して判断を求める。

## Implement the smallest durable change

- 既存format、生成元およびrepositoryの標準taskを使う。Generated fileとlockfileはownerを特定して正規手順で更新し、推測で手編集しない。
- 補助toolの設定はupstream標準をbaselineとし、依頼に必要な最小差分だけを持つ。成果物を経緯から切り離して読み、不要なcompatibility layer、旧経路、alias、分岐、commentおよびdocumentを残さない。
- Module等の移動・分割・責務再配置では、対象の実装本体を新しい場所へ移し、内部参照も新経路へ更新する。旧経路のre-export等は確認済みの公開互換性契約に必要な場合だけ残す。実装本体を移せなければ移動完了とせず、理由と残作業を報告する。
- Program経路を追加・変更する前に `$design-program-observability` で適用判定する。対象なら [program observability contract](../../references/agent-computer-interface-observability.md) に従い、変更経路と再利用される共有境界だけを準拠させる。
- 不具合修正は先に `$investigate-problem` で原因とoracleを確定する。[failure oracle and causal verification](../../references/failure-oracle-and-causal-verification.md) に従い、既存証拠でfailure段階を識別できなければproduct fixより先に最小観測経路を作る。
- READMEはsoftwareの利用者向けとし、公開APIを使う開発者も利用者に含める。Repositoryを変更する開発者向けのbuild、test、検証情報やtaskへの案内はREADMEに置かない。Public behavior、CLI、設定または公開APIを変えた場合は、影響する利用者向け文書を同じ変更で更新する。
- Architectureの俯瞰文書は責務、境界および主要なdata flowを表し、関係する変更に合わせて更新する。関数単位の処理手順や実装の言い換えは書かない。
- 実装の詳細、内部の意図および不変条件はcode、型、comment、testを原典とする。実行方法とその意図はmise taskなどの実行可能な原典に置き、AGENTS.mdには原典から読み取れない抽象的な行動原則だけを書く。場面別のtask選択や起動手順を転記しない。
- 実装やtaskを説明するだけの文書は作らない。実装変更で古くなる既存の該当記述は、その変更に関係する箇所を削除する。

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

- Commit前に元の依頼とclosed setを読み直し、各項目を証拠、明示的な対象外または残作業へ対応付ける。Git stateとdiffを再確認し、release対象では開始時の提案が送信済みであることと、task全体の承認済みrelease要否・上限と予定するcommit群の影響を照合する。提案の送信漏れが判明したら直ちに送り、commitなしでできる残作業を進める。未承認、SemVerで基準releaseを確認できず影響が確定しない場合、または範囲外ならcommitを保留して残作業と必要な判断を示す。Commitできる場合は自分の変更だけを明示的にstageして論理単位でcommitする。未確定のまま残す明示指示がなければ、完了した変更はlocal commitへ確定する。
- Commit messageは上記のrelease規則とrepository慣習に従い、目的、主要理由、範囲、user-visible effect、migrationおよび主要検証を自足的に記す。Release対象以外で慣習不明なら英語のConventional Commitsを使い、Codex co-author trailerを付ける。
- Commitを作ったtaskは [Git task evidence](../../references/git-task-evidence.md) をすべて読み、最終commitをanchorに標準noteを保存する。Codexではcomplete thread履歴の取得・照合が必須で、不能ならtaskを未完了とする。他runtimeは同等capabilityがなければskipと境界を明示できる。
- Agentが既存noteを読み、semantic conflictを解消し、分類・redaction・要約済みのnormalized bodyを作る。既存blob IDまたは`absent`を指定して `scripts/update-git-task-note.ts` を使い、schemaまたはCAS conflictでは上書きせず停止する。Helperへraw threadを渡さない。

## Remote writes and completion

- Push、remote ref更新およびPR作成は、ユーザーの明示依頼または対象refを含むrepository guidanceのstanding authorizationがある場合だけ行う。Authorizationだけでは実行を要求せず、guidanceが自動実行も指示する場合に実行する。ユーザーの明示的なno-pushまたは狭いscopeをstanding authorizationで上書きしない。PRは指定がなければready for reviewとする。
- Push前にcodeとnotesをfetchしてstateを再確認する。Codeをnon-force pushした後、local notes refがあれば別のnon-force pushで送る。Notes競合は別refへfetchして意味を保持してmergeし、解消不能ならcodeとnotesのpartial stateをblocked handoffする。Code pushをrollbackまたはforceしない。
- 成功条件とconstraintがすべて証拠付きで満たされた場合だけ完了する。未達が解消不能ならpartialまたはblockedとして、確認済み範囲、未確認結果、理由および必要な次のactionを示す。

## Repository profile

- `origin`のGitHub ownerが`atty303`なら [atty303 engineering policy](references/atty303-engineering-policy.md) を読む。Owner不明時は配置と依頼から推定し、適用規則を変える不明点だけ確認する。
- Other repositoryではその方針を優先し、`atty303` profileのImplementation Style、Comments、Testing Strategyだけを設計選好として使う。依頼に不要な`mise`、CIその他の基盤は導入しない。
