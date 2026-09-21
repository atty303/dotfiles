---
name: develop-repository
description: 開発、修正、リファクタリング、レビュー対応など、リポジトリを変更するタスクで、対象リポジトリに応じた観測可能な実装、検証、ドキュメントおよび再現性の方針を適用する。
---

# Development Tasks

## Common

- 明示的な指示がない限り、開発タスクによる変更は対象リポジトリ内に限定する。
- `origin` がない、またはGitHub ownerを判定できない場合は、配置、作成目的および依頼の文脈から
  `atty303` またはOtherを推定する。適用規則に影響する不明点が残る場合だけ確認を求める。

### Solution Framing

- 実装前に、依頼、適用guidance、repositoryの原典および実環境から、目的、observableな成功条件、hard constraint、明示された手段および未検証の前提を確定する。この整理だけのためにrepository文書を作成しない。
- ユーザーが承認した計画、設計まとめ、checkpointまたはその他の実装原典がある場合は、変更前にその全項目をclosed setとして列挙し、各項目をobservableな成功条件、hard constraint、明示的なnon-goal、確認済みの選択または未検証の前提へ分類する。曖昧な上位目的へ統合して項目を消失させず、実装中も同じ項目集合と対応を維持する。この照合だけのためにrepository文書を作成しない。
- 存在が示された実装原典の全項目を取得できない場合、または適用authority間の衝突により項目集合、分類もしくは達成判定を確定できない場合は、欠落を推測で補わず確認を求め、解消するまでtask全体を完了扱いにしない。独立した範囲を継続できる場合は未完了境界を保ち、継続できない場合はblocked handoffとする。
- Requested pathと、repository変更なし、既存機構の利用、削除、簡略化または前提変更を含む最小コストのviable alternativeを、成果差と継続的な保守コストに比例する範囲で比較する。同等の結果を得る内部設計は自律的に選択するが、user-visible contract、scope、migration、dependency、権限、外部影響、互換性または保存dataを変えない。
- 明示された技術または構造からの逸脱は、前提の誤り、目的への阻害またはmaterialな成果差もしくは複雑性差をsourceや実環境から確認できる場合だけ提案する。現案、代替案、前提差、保守コスト、利用者への影響および推奨案を一度に示し、承認されるまで明示手段を変更しない。差が僅か、未検証または成果に影響しない場合は再交渉しない。
- 実装中に前提の崩壊、目的を満たさない経路または不釣り合いな複雑化を検出した場合は、局所的な追加実装を止めてsolution framingへ戻る。主要contractを変えずに解消できなければ、変更を続ける前に確認する。

### Artifact Profile and Control Domain

- 変更前に、成果物を`spike`または`durable`へ分類する。`spike`は仮説検証用で、そのままrelease、常用、再利用または運用依存されない成果物とする。`durable`はそれらのいずれかを想定する成果物とする。一時領域だけで完結して残さない検証コードは`spike`と判断できるが、repositoryへ残す変更は依頼、計画またはrepositoryの原典で非本番の仮説、終了条件およびpromotion条件を確認できない限り`durable`とする。既存のdurableな経路を実装都合で`spike`へ降格しない。
- 既定のtrusted control domainを、同一利用者が所有・管理するpersonal computing environment全体とする。明示的な相互不信またはisolation contractがない限り、そのmachine上のaccount、UID、root、process、service、filesystem、local IPC、containerおよびVMを同じdomainに含め、分離単位だけを理由に敵対者を仮定しない。
- 外部主体が制御するnetwork endpointとの入出力、成果物が入力または未検証payloadとして受け入れる外部主体が内容を制御するdataまたは実行code、他人、別organizationまたは外部serviceが所有するaccount、credentialまたはresource、明示されたmulti-tenant環境または相互不信、保証対象であるsandbox、account、containerまたはVM間のisolation、および配布・運用主体の変更で新しく加わる外部主体をtrust boundaryとする。これらのdataとcodeはlocalへ保存した後もcontrol provenanceを維持する。正規の採用手順で固定・検証され、trusted domainのcomponentとして扱うdependencyまたはtoolは、外部由来であることだけではdomain外主体とみなさない。loopbackまたはlocal IPCは、それ自体で境界とせず、control domain外から到達する場合だけ境界とする。
- Trust boundaryとoperational safetyを分ける。同一利用者のrootと一般UIDを敵対者関係とはみなさないが、authority、irreversibilityおよびblast radiusが増す操作は、誤削除、system破損、data lossおよび復旧可能性の観点で確認する。誤入力、partial write、crash、timeout、並行実行およびcleanup失敗は、攻撃ではなく到達可能なcorrectnessまたはreliabilityとして扱う。trustedな利用者による自身の設定や状態の意図的改変は、明示的なintegrity contractがない限り防御しない。Secretは値が与える認証、認可、復号、署名またはなりすまし能力、confidential contentは明示的な非公開contractで識別し、control domain外への送信、記録または共有を防ぐ。Operational identifierの存在だけを漏洩とみなさない。
- `spike`では、仮説を判定できること、意図しないdata loss、control domain外へのsecretまたは明示的なconfidential contentの漏洩、現在の出力contractに含まれるpublicまたは無関係な外部sinkへの不要なprivacy-sensitive dataおよび個人・host固有operational identifierの送信・公開、authority逸脱を防ぐこと、および作成した一時resourceをcleanupできることだけを完了条件とする。trust boundary外との入出力が仮説に含まれる場合だけその経路を確認し、本番化しなければ価値のないhardeningを実装しない。検証済みの本番化懸念は重複排除し、該当する既存のplan、statusその他のrepository原典があればそこへ、なければ最終handoffの短いpromotion checklistへ集約する。Checklistだけを保存する新しいrepository成果物は作らない。
- `spike`を`durable`へ昇格するときは、残す成果物全体についてcontrol domain、外部由来入力、外部resourceおよび保護対象を再確定し、spike時の確認をreview済みとみなさず、durableな成果物として検証とfresh reviewを行う。

### Repository State

- Repository操作には通常の`git` commandを直接使う。Git repositoryとして解決できなければ停止し、別のVCSのmetadataを検出、解釈または操作せず、repositoryの初期化や移行も行わない。
- 開発タスクの開始時は、変更前にremoteがあればfetchし、branch、upstream、HEADと親、index、working tree、default branchおよび必要なdiffをGitから確認する。リポジトリを変更しない調査、説明および外部serviceの参照だけならfetchしない。
- Codeのfetchが失敗してもlocal stateは確認できるが、remote参照が古い可能性を明示して作業可否を判断する。Git notesはcodeとは別に標準`refs/notes/commits`をfetchする。Remoteにnotes refがない状態は失敗とみなさず、fetchまたはmergeに失敗した場合はlocalとremoteのnoteを暗黙に置換しない。別commitのnoteは意味を保持して統合し、同じcommitの競合は解消できなければ停止する。Git notesは履歴の補足面であり、secret、confidential contentまたはrepositoryへ含められないprivacy-sensitive dataを置くprivate sinkとして扱わない。
- Current tree、source、testおよびliving documentationだけでは、変更意図、未完了範囲、migration、実機検証、棄却経路または判断理由が分からず、現在の判断が変わり得る場合はGit logと標準notesを探索する。明示的な履歴調査またはtask再開でも探索する。最初は関連path、schema、featureまたは既知commitへ限定し、必要な場合だけ広げる。履歴はdescriptiveな証拠であり、現在のsource、test、living documentationおよび最新のユーザー指示を上書きするnormativeな原典にしない。現在の挙動またはscopeを左右する衝突が解消しなければ推測せず確認する。
- ユーザーが指定したbranch、依頼に対応する既存branchまたは未完了commitがある場合は、その継続を優先する。新しい独立した変更では、repoの運用規約、未統合変更、依頼との関連性およびPR作成要否から、default branch上で直接作業するか、最新のremote default branchを起点にbranchを作るかを判断する。現在のbranchに無関係な変更がある場合は、そこから新しい変更を派生させない。
- 意図しない作業開始点、古いdefault branchまたは依頼と無関係なbranchを検出した場合は、ユーザー変更と公開済み履歴を保持したまま作業開始点を適正化する。履歴のrewrite、既存branchの移動または未確定変更を伴う切替が必要なら、影響を示して事前確認を求める。
- Commit前にGit stateを再確認し、HEADと親、branchとupstream、index、working tree、diffの範囲および既存のユーザー変更との分離が、開始時に選択した作業線と一致することを確認する。長時間の作業やremote default branchの更新が統合判断に影響する場合は再fetchする。Default branchが進んだことだけを理由に自動でmerge、rebase、rewriteまたはbranch移動を行わない。
- 確定対象を確認後、自分の変更だけを明示的にstageし、indexに対象外のpathがないことを確認してcommitする。Working tree全体が対象であると確認済みの場合だけ全変更をstageする。CommitにはCodexのco-author trailerを付ける。Commit messageはユーザー依頼と合意事項を要約し、変更目的、主要理由、変更範囲、user-visibleな影響、migrationおよび主要検証を該当する範囲で自足的に記載する。設計依頼、深掘り、実装依頼を経るtask cycleでは、次項で定義するcycle全体をcommitの文脈とする。複数commitでは最初のcommitにtask起点の要約を置き、後続commitには最初のcommit IDと固有の変更理由・差分を記載する。
- Commitを一件以上作成したtaskでは、note作成または更新自体がblockerである場合を除き、完了またはblocked handoffの前に、最終commitをanchorとしてtask cycle全体を一つの標準`refs/notes/commits` noteへ自動保存する。Task cycleは、直前のcycleが閉じた後に現在の目的を開始した最初のuser messageを起点とし、ユーザー目的の達成を明示した最終handoff、明示的なblocked handoff、またはユーザーによる明示的な中止・別taskへの置換で閉じる。別taskへの置換を明示したuser messageは旧cycleの終端と新cycleの起点を兼ね、各cycleがnote作成対象である場合にそのTranscriptへ記録し、両cycleが対象なら両方へ記録する。そのmessage後のagent応答、tool操作、観測および判断は、旧cycleを閉じるための処理だけを旧noteの`A:`へ、新しい目的への処理だけを新noteの`A:`へ分け、同じ処理を両方へ重複記録しない。Final channelの使用自体は境界とせず、調査結果、途中要約、status回答および方針確認の応答後も同じ目的のcycleを継続する。達成またはblocked handoffを送ると判断した時点をpre-handoff checkpointとし、未送信のhandoff本文を予測してTranscriptへ書かず、それ以前の実履歴をnoteへ保存する。Note保存後にhandoffを送りcycleを閉じ、同じthreadの後続依頼は新しいcycleとして以前のanchor noteを変更しない。ただし必須noteが未保存のblocked handoffでは、他のblockerの有無にかかわらずcycleを閉じず、再開時に同じanchorへのnote保存を完了してから残るblockerについてcycleを閉じるか判断する。新cycleにcommitがなければnoteを作らない。Noteには開始commit、作業線、taskで生成したcommit列と対応、主要guidanceとskill、重要な環境・権限条件、主要操作と観測を要約し、人間が入力または選択した全messageを元言語・全文で時系列に残す。同じ時系列でagentの応答、tool操作、観測および判断を要約する。自動注入されたskill本文、`AGENTS.md`、plugin一覧、app contextおよび環境情報はraw user messageへ含めず、simulationに必要な条件だけを要約する。添付または外部artifactは複製せず、論理名、digestおよび必要な性質を記録する。Note本文を作る前に、cycle起点、cycle内の全user messageおよび末尾user messageを列挙し、利用可能なruntimeのthread履歴と照合する。Current context、compaction summary、以前のagent要約または直近の依頼だけを全文履歴の代用にしない。Runtimeからcycle全体のthread履歴を取得または照合できない場合は、欠落を推測で補わず、noteを作成せずにtaskを未完了とする。人為的な容量上限やtruncateを設けず、長い本文はagent-owned temporary fileから`git notes --ref=commits add --no-stripspace -F FILE`へ渡し、実際のGitまたはtool制約で保存できなければtaskを完了扱いにしない。
- Noteは、task、anchor、base、作業線、commit対応、主要guidanceおよび実行条件を一行単位のmetadataとして先頭に置く。次に再取得が高コストな証拠がある場合だけ`Evidence`、続けて現在の原典を示す一行の`Authority`を置き、`Transcript`を必ず最後にする。Transcriptはexchangeごとに一段目を`U<n>: <元のuser message>`、その直下の二段目を`A: <agent要約>`とする親子箇条書きにし、roleごとの見出しや空行を反復しない。複数行のuser messageは`- U<n>:`に続けて各原文行へ構造用の4空白を付け、agent要約には2空白の`- A:`だけを予約する。構造用prefixを原文に含めず、原文行が`- A:`や`- U<n>:`で始まっても役割境界を一意に復元できるようにする。User入力間に連続するagent応答、tool操作および観測は対応する二段目へ時系列で圧縮する。短い選択入力も原文のまま残し、二段目で質問と選択の意味を補う。
- 前項の全文保存要件よりredactionを常に優先する。Noteはremote repositoryと同じ可視性を前提とし、secret、confidential contentおよび公開先に不要なprivacy-sensitive dataは型付きplaceholderへ置換してsimulationに必要な性質を要約する。Hostname、path、UUID、digestおよびcommit IDなどのoperational identifierは、それだけを理由に置換しない。主要な変更理由とuser-visibleな影響はnoteだけに置かずcommit messageを自足させる。
- 全thread以外の詳細な調査証拠、検証環境または棄却案は、再取得が高コストまたは不可能で、commitの解釈、運用または再検証に重要な場合だけnoteへ加える。Current tree、commit messageまたは容易な再実行から復元できる情報は重複させない。ここでいう既存noteは今回のanchorに付くnoteを指す。Note更新前に`git notes --ref=commits show`で既存本文を読み、意味を保持して重複排除した統合本文をagent-owned temporary fileへ作る。既存noteがなければ追加し、あればread-before-writeで再確認した上で`git notes --ref=commits add -f --no-stripspace -F`を使って置換する。独立内容は統合する。Current source、test、living documentationおよび最新のユーザー指示で解消できない意味的衝突、または読み取り後に既存noteが変化したことを検出した場合は上書きせず、衝突内容とanchorを示してユーザー確認を求める。失敗時は安全に再試行し、解消できなければcommitをamendせず未完了として報告する。完了報告にはnoteの対象commitと目的を一行で含める。
- Pushはrepository guidanceで事前承認されている場合またはユーザーが明示的に依頼した場合だけ行う。Push前にcodeと標準notes refをfetchし、branch、upstream、index、working treeおよびremoteとの差をGitで再確認する。Codeをnon-force pushした後、localに標準notes refがあれば、現在taskでnoteを変更したかにかかわらず`refs/notes/commits:refs/notes/commits`を別のnon-force pushとして送る。Codeだけ成功した場合はpartial stateを明示し、remote notesを確認できるまでpush依頼を完了扱いにしない。Notes pushが競合した場合は上書きせず、remote notesを別refへfetchし、意味を保持してmergeした後にnotesだけを再試行する。解消できなければremote code refとlocal notes refを示してblocked handoffする。Code pushはrollbackまたは再実行しない。

### Change Cost

- コード、設定、テスト、文書、コメント、互換処理およびcommitを、すべて継続的な保守コストとして扱う。変更前に、現在の要求をrepo変更なしの操作、既存成果物の削除・簡略化、または既存機構の利用では達成できないことを確認する。
- 要求された永続性、再現性および配置を含む同じ範囲の正しさを得られる場合は、永続成果物なし、削除・簡略化、既存成果物の変更、新規成果物の順に優先する。自動化、宣言性、網羅性または新機能の利用だけを追加理由にしない。
- 一時的な環境状態、原因または反証により恒久的な再発経路がないと確認した失敗経路および未確認の将来要件を、恒久的なコード、移行処理、テスト、コメントまたは文書へ変換しない。
- commit前に、最終成果物をdiffや実装経緯から切り離し、目的と成功条件を満たすか、不要な構成がないか、および前提変更で除去できる複雑性が残っていないかを確認する。追加・変更が現在の具体的要件に必要で、同じ正しさを得るより保守コストの低い代替がないことを説明できない場合は、不要な追加を削除し、不要な変更を取り消す。永続変更が残らなければcommitしない。

### Problem Fixes

- 不具合、障害、回帰または期待と異なる挙動を修正する場合は、product codeを変更する前に
  `investigate-problem` を使用する。利用者が失敗と判断した最終状態、保持済みdiagnostic run、failure oracleおよび原因を
  確認してから修正へ進む。
- 原因を修正した後は、変更した不変条件から利用者のfailure oracleまでのproduction経路を再評価し、修正によって新しく到達可能になったdownstream state、callerとconsumer間の意味変換、retry、re-entryおよび逆操作を確認する。局所failureの消失または中間状態の成功を最終oracleのpassとみなさない。再評価は変更によって到達性または意味が変わった経路に限定し、無関係な関連codeへ探索を広げない。
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
- Failure oracleを証明するtestは、変更した不変条件からoracleまでに実際に存在し、変更で到達性または意味が変わったproductionのcaller、dispatcher、consumerおよびstate transitionを通す。Fakeまたはmockで外部境界を置換してもよいが、境界より後の成功状態を直接生成するtestは、その手前までの局所証拠として扱い、最終結果のcompletion gateにしない。最終contractがleaf functionの返り値やrequest発行で終わる場合は、そのboundaryより後を要求しない。対象環境を実行できない場合は、実装経路の検証済み範囲とfailure oracleが未確認であることを分けて報告する。
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

- Commit、完了を示す最終報告および必須reviewの開始前に、diffや実装経緯から離れて、元の依頼、受理済み計画および現在のrepository原典を再読する。計画の各項目を、達成済みならobservableな証拠、対象外ならその根拠となる明示的なauthority、未達または未検証なら残作業へ一対一で対応付ける。Reviewへ渡すacceptance criteriaも同じ項目集合を保持する。
- 成功条件とhard constraintがすべて証拠付きで達成され、non-goalとの境界が保たれ、未達または未検証項目がない場合だけtask全体を完了とする。依頼範囲内で解消できる未達は作業を継続し、解消できない項目が残る場合はpartialまたはblockedとして未達項目と必要な次のactionを報告する。局所test、build、reviewまたはcommitの成功だけで、対応付けられていない計画項目を達成済みとみなさない。
- `durable`な変更をローカルcommitとして確定する前に、[$review](../review/SKILL.md)をすべて読み、成果物が実際に越えるtrust boundaryとoperational safety上のblast radiusに比例したfresh subagent reviewを完了する。`spike`は独立レビューを必須とせず、上記の目的限定の完了条件を実装者が確認する。明示的にspikeのreviewを依頼された場合は、`review`へartifact profileと目的限定のacceptance criteriaを渡す。
- 複数の論理単位がある場合は、変更の結合度とリスクから、タスク全体または論理単位ごとのレビューを選ぶ。
- 指摘を`review`が定める基準で自動対応、棄却またはユーザー判断へ裁定する。自動対応とユーザーが採用した対応対象だけを一括修正して関連検証を再実行し、比例的な再確認と最終diffの完了条件を満たす。
- 必須となる独立レビューを完了できない場合は通常のblockerとして扱い、該当するdurableなcommitを完了扱いにしない。

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
