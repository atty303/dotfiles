# Agent-Computer Interface向けプログラム観測契約

Status: Living Standard  
Last updated: 2026-08-20

## 目的

この文書は、coding agentが開発対象プログラムの実行結果を調査できるようにするため、プログラムが通常利用時から
提供する観測面の意味契約を定める。人間が不具合へ遭遇した時点の証拠を保持し、agentが再現や一時ログの追加より先に
実際の失敗runを調べられる状態を標準とする。

この観測面はAgent-Computer Interface（ACI）の一部である。compiler、test runner、VCS、sandbox、GUI操作toolなど、
開発workflow全体のinterfaceは本書の対象外とする。ただし、それらが生成した構造化結果やscreenshotなどを、開発対象
プログラムのrunへ結び付けるartifactとして参照できる。

本書は個人の全agent開発に対する原典である。他者のrepositoryでは、そのrepository固有の方針を優先する。
OpenTelemetry（OTel）のdomain modelとSemantic Conventionsを観測語彙の基準にするが、OTel SDK、OTLP、Collector、
特定backendまたは共通wire formatの採用を要求しない。

## 規範語彙

- **必須**: 適用対象が満たさなければならない条件。
- **推奨**: 原則として満たす条件。逸脱する場合は、同じ目的を満たす方法と理由を説明できなければならない。
- **任意**: 対象の規模、runtimeおよび既存機構に応じて選択できる条件。

## 適用判定

### 既定で適用する処理

次のいずれかを含む処理には、独立した観測面を実装することを必須とする。

- network、filesystem、database、credential store、外部process、deviceまたは別runtimeとの境界
- 利用者データ、設定または外部resourceの状態変更
- 非同期、並行、queue、worker、retry、timeoutまたはcancellation
- 複数段階の処理で、同じ最終症状が異なる段階のfailureから生じ得る経路
- timing、外部状態、利用者環境などにより再現が困難になり得る経路

CLI、GUI、service、libraryという配布形式だけでは適用可否を決めない。短命なCLIでも複数の外部境界や状態変更を持つなら
適用対象であり、長時間動作するprogramでも純粋かつ決定的な処理だけなら各処理へのinstrumentationは不要である。

### 除外できる処理

次の条件をすべて満たす処理は、独立した観測面を省略できる。

- 短く同期的かつ決定的である。
- 失敗がtyped error、exit statusまたは既存のpublic interfaceから失われない。
- どの処理がなぜ失敗したかを既存の出力から一意に識別できる。
- 通常利用時の記録を保持しなくても、同じ入力から安全かつ安価に再実行できる。

単に実装量が少ない、CLIである、testがある、または現在再現できていることだけを除外理由にしてはならない。

### Applicationとlibraryの責務

applicationは、観測の有効・無効、recording、保持、削除およびexportを所有する。libraryはOTel SDK、exporter、保存先または
global providerを独自に構成してはならない。libraryが観測情報を生成する場合は、host applicationが提供するAPI、provider、
contextまたはdiagnostic sinkを使用し、consumerがない場合にも正常に動作する。

## Interfaceの分離

プログラムは次の三つの面を分離する。

| 面 | 役割 | 例 |
| --- | --- | --- |
| 結果面 | 利用者が要求した結果を返す | stdout、API response、生成file、画面表示 |
| 操作面 | 実行、取消および結果判定を制御する | CLI引数、API、cancel、exit status |
| 観測面 | 実行の因果関係と内部状態を診断する | operation、event、error type、artifact参照 |

stdout、stderr、API responseまたはUIを、agent向け診断情報のtransportとして歪めてはならない。特にpublicなstdoutへdebug
messageを混在させたり、問題調査のためにstderrへ内部状態を列挙したりしない。stderrやUIには利用者が理解または対処できる
情報を出し、内部failureを関連付ける必要がある場合は安定したdiagnostic run IDを提示する。

観測面は結果面と同じcode pathを観測しなければならない。診断専用の代替実装だけを通して、通常利用の挙動を推測しては
ならない。

## 意味モデル

実装方式にかかわらず、観測面は次の概念を表現できることを必須とする。名称と関係はOTelのdomain modelを基準とする。

### Diagnostic Run

一回の利用者操作、CLI invocation、request、jobまたは調査対象実行を識別する単位。run IDはoperation、event、artifactおよび
利用者向けdiagnostic IDを相関できる安定した識別子とする。複数processまたはruntimeにまたがっても、同じ論理実行を追跡
できることを推奨する。

runは記録の完全性を`complete`、`partial`または`dropped`として識別できなければならない。`partial`または`dropped`では、
容量超過、queue drop、flush timeout、保存失敗、crashなどの欠落理由と、判明している場合は欠落件数または範囲を示す。
完了markerをrecord本体とatomicに公開できない場合、markerのないrunを`partial`として扱う。run自体を保存できないfailureは、
recording subsystemのhealthまたはdegradation状態から確認できるようにする。agentは欠落を事象の不在として扱ってはならない。

### Resource

観測情報を生成した実行主体を表す。少なくともprogramまたはservice名とversionを識別できることを必須とし、診断に必要な
場合はruntime、OS、architecture、deployment environment、processまたはbuild identityを含める。

host固有値や利用者identityをresourceへ含める場合は、診断上の必要性、cardinality、保存先およびprivacyを確認する。利用者が所有するlocal recordingでは必要なoperational identifierをallowlistできるが、remote exportまたはpublic artifactでは目的に不要な個人・host固有値を最小化する。

### Operation

開始と終了を持つ一つの処理段階。安定した低cardinalityの名前、開始・終了時刻、status、親operationまたは関連linkを持つ。
外部境界、状態変更、timeoutやretryを所有する境界、および異なるfailureを区別するために必要な段階をoperationにする。

functionごとにoperationを作ったり、入力値をoperation名へ埋め込んだりしてはならない。

### Event

operation中に発生した離散的な事象。状態遷移、retry開始、fallback選択、signal受信など、独立したdurationを持たないが因果関係の
理解に必要な事象に使用する。連続的なdebug messageや同じexceptionの重複記録には使用しない。

### StatusとError Type

operationの最終statusは少なくともsuccess、error、cancel、timeoutを区別できなければならない。statusだけで原因を表さず、
failureには安定した機械可読のerror typeを付ける。

error typeには`timeout`、`permission_denied`、`schema_invalid`のような分類を使う。exception message、HTTP response body、path、
利用者入力または動的IDをerror typeにしてはならない。既存のOTel Semantic Conventionsが対象domainを定義している場合は、
そのstatusと`error.type`の語彙を推奨する。

### ContextとLink

process、thread、async task、queueまたはruntime境界をまたいでrunとoperationのcontextを伝播する。親子関係で表せないretry、
fan-out、batch、producer/consumerまたは別runとの関連はlinkとして表現する。

contextは認証情報や任意の利用者dataを運ぶ経路にしてはならない。

### Artifact

screenshot、video、DOM snapshot、state snapshot、構造化test結果、redacted response shape、生成物またはcore dumpなど、eventや
attributeへ埋め込むべきでない証拠を参照する。artifactにはkind、生成元operation、取得時刻、保存場所、schemaまたはformat、
保持条件および機密性を関連付ける。

artifactの存在だけで成功を断定せず、対象boundaryのstatusおよび期待結果と照合する。

### AttributeとSemantic Conventions

attributeはoperation、event、resourceまたはartifactを分類し、仮説を比較するための構造化された値とする。記録可能なkeyと
値の種類をallowlistで定義し、必要性、意味、単位、cardinalityおよび機密性を確認する。

既存のOTel Semantic Conventionsが適合する場合は再利用する。独自のattribute、operation名またはerror typeを追加する場合は、
同じ概念へ複数名を作らず、意味と安定性を対象programの原典で定義する。

## Error処理と観測の責務

telemetryは制御フロー上のerror処理を置き換えない。typed error、Result、exception cause、exit statusおよびcallerとの契約は、
観測の有効・無効にかかわらず保持する。

- 下位層は原因を失うboolean、空値または文脈のないerrorへ変換せず、causeをcallerへ伝える。
- operationを所有する境界が、そのoperationのfailureとerror typeを一度記録する。
- 同じexceptionを複数階層のeventやlogとして重複記録しない。
- retryやfallbackで回復し、最終結果が成功した内部failureを、最終operation全体のfailureとして扱わない。
- 意図したcancellationをerrorやtimeoutと混同しない。
- recording、processorまたはexporterのfailureを、本来のoperationのerrorへ変換しない。

利用者向けmessageは、利用者が理解できる影響と回復方法を伝える。診断用attributeは、agentが処理段階と原因候補を識別する。
一方を他方の代用にしてはならない。

## 通常利用時のRecording

### 既定動作

適用対象programではinstrumentationと有界なローカルrecordingを既定で有効にし、利用者がopt-outできるようにする。remote
service、別machineまたはcloud backendへのexportは別の明示的なopt-inとし、既定で無効にする。

観測を無効化した場合、recordを生成または保存せず、最小限のno-op instrumentation以外の処理を行わない。無効化によって、
観測recordとその管理状態を除く結果面、操作面、本来のprogramの永続状態または外部副作用を変えてはならない。

### 短命process

短命processでは一回のrunを有界bufferへ記録する。programがsuccessと判定しても、誤った出力、欠落した副作用または誤表示を
利用者が後からfailureと判断できるため、直近の正常runを有界な猶予期間または件数だけ診断可能な内容で保持する。終了前に
利用者がfailureを確実に判定してfreezeできる経路がある場合だけ、正常runを即時破棄できる。error、timeout、crashおよび
利用者が明示したrunは優先して保持する。終了時のflushは有界とし、診断保存のためにprocess終了を無期限に待たせない。

### 常駐process

常駐processでは容量または期間で制限したrolling bufferを使用する。古い正常runから破棄し、error、timeout、crashまたは
利用者のproblem reportを契機として、対象runと必要な前後windowをfreezeできるようにする。

### 保持と利用者control

共通の保持日数や容量は本書で固定しない。各applicationは次を定義し、利用者が確認または操作できるようにする。

- recordingの有効状態とopt-out方法
- 保存場所とaccess permission
- 最大容量または保持期間
- 正常run、失敗runおよびfreeze済みrunの削除条件
- 保持済みrunの一覧、削除および安全なexport方法
- remote exportがある場合の送信先、対象dataおよび明示的な有効化方法

## PrivacyとSecurity

観測dataは、後段で削除する前提ではなく、instrumentation時点のallowlistによって最小化する。

情報は文字列の見た目ではなく、値が与える能力、明示的なconfidentiality contractおよび保存・出力先で分類する。

- `secret`: 所持により認証、認可、復号、署名またはなりすましが可能な値。
- `confidential content`: 利用者、repository、契約またはdata ownerが非公開と指定した本文またはdata。
- `privacy-sensitive data`: 実名、email、住所、位置、行動履歴、会話、画面または個人fileの内容など、公開先と必要性により扱いが変わるdata。
- `operational identifier`: usernameを含むfilesystem path、hostname、account名、IP、PID、port、device名、repository path、UUID、digestまたはcommit IDなど、実行や診断を識別する値。明示的な別contractがない限りsecretではない。

高entropy、長い文字列、private permissionまたは環境固有性だけをsecretの根拠にしない。Credential形式、auth field、値が与える能力または明示的なconfidentiality contractから判定する。

credential、access token、refresh token、API key、cookie、private keyおよび認証headerのraw値または復元可能な表現は、
観測recordとartifactへ記録してはならない。診断に必要な場合も、credential種別、key ID、期限など、秘密値そのものではない
明示的にallowlistされたmetadataだけを使用する。非可逆fingerprintは入力空間と照合可能性を評価し、秘密値の推測または
照合に利用できない場合だけ使用できる。

Requestまたはresponse body、clipboard、入力文、会話、画面および個人fileの内容は、必要性と安全な表現を明示的に定義した場合だけ記録する。Email、実名その他のprivacy-sensitive dataはsecretとは呼ばず、利用者が所有するlocal recordingでは診断に必要な範囲をallowlistできるが、remote exportまたはpublic artifactでは目的に不要な値を最小化する。

完全なfilesystem pathを含むoperational identifierは、利用者が所有するlocal recordingでfailureの識別に必要ならallowlistできる。URL query、command line、exception message、stacktrace、environment variableまたはprocess environmentの全体は一括記録せず、必要な個別fieldを分類してallowlistする。Credentialまたは署名付きURLを含み得るfieldはraw値を記録しない。

hash化は常に匿名化になるとは限らない。入力空間が小さいidentifierをhash化するだけで安全と判断しない。Collector、processor
またはexporterでのfilterとredactionは防御層として利用できるが、sourceでのdata minimizationを置き換えない。

保存dataとartifactは利用者dataとして扱い、最小permission、明示的な保持上限および削除経路を持たせる。agentは依頼された
調査に必要なrunだけを読み、診断dataを無関係な外部serviceへ送信しない。

## 非干渉性とResource上限

観測面は本来のprogram semanticsから分離する。

- consumer不在、recording無効、容量超過、保存失敗またはexporter停止で、本来の結果を変更しない。
- stdout、stderr、API response、exit status、および観測recordとその管理状態を除く本来のprogramの永続状態と外部副作用を
  変更しない。
- 観測用queue、buffer、flush、shutdownおよびretryに、時間、memory、diskおよび試行回数の上限を設ける。
- 観測面自身のfailureは、runの完全性またはrecording subsystemのdegradation状態として確認できるようにするが、再帰的な
  failure loopを作らない。
- 高価なattribute計算やartifact生成は、記録の必要性を判定してから行う。

有効時の観測には有限の性能costがある。対象programは、そのcostが利用者向けlatency、timing-sensitiveな挙動またはresource
制限へ与える影響を検証し、受け入れられない場合は記録粒度、bufferまたはartifact生成を調整する。failureをランダムsamplingで
失わないことを優先し、正常runの破棄、tail側の選択または有界bufferで量を制御する。

## Agentによる調査順序

人間が通常利用中に遭遇した不具合を調査するとき、agentは次の順序で進める。

1. 利用者が失敗と判断した最終状態、操作、おおよその発生時刻および対象環境を確認する。
2. 再現またはinstrumentation追加より先に、該当する保持済みdiagnostic runを探す。
3. resource、operation tree、status、error type、event、linkおよびartifactを実際の失敗に関する一次証拠として確認する。
4. 観測事実、仮説、推論および未確認事項を分離し、記録だけでは判断できないboundaryを特定する。
5. 未確認boundaryに限って、同じ条件のreplay、再現testまたは追加観測を行う。
6. 観測不足が判明した場合は、場当たり的な一時ログではなく、本書の意味契約に沿う最小の恒久的観測経路として補う。
7. 修正後は同じfailure条件または対応する回帰contractで結果を検証する。

保持済みrunは再現前の一次証拠であるが、timing、外部状態または未記録の入力との因果関係まで自動的に確定しない。別条件の
成功を修正確認の代用にせず、必要なreplay、testおよび反証を省略しない。

## Conformance Scenario

適用対象programは、関連するscenarioを満たすことを確認する。

| Scenario | 合格条件 |
| --- | --- |
| Programが検出したfailure | 後からrun ID、resource、失敗operation、処理段階、error typeおよび関連artifactを取得できる |
| 利用者がfailureと判断したsuccess run | 記録の完全性、operation tree、最終status、関連artifact、およびprogramがfailureを検出していない事実を確認できる |
| Recordingのopt-out | recordを保存せず、観測面自身の状態を除くstdout、stderr、exit status、永続状態および外部副作用が有効時と同じ契約を保つ |
| Recording/export failure | 保存先障害、容量超過またはconsumer不在でも本来のoperation結果を変更しない |
| 部分記録とdrop | runの完全性、欠落理由と既知の欠落範囲、またはrecording subsystemのdegradationを確認できる |
| Remote未設定 | 診断dataをprocess外のremote destinationへ送信しない |
| Asyncとretry | 親子context、link、試行と最終結果を区別できる |
| Timeout、cancel、crash | 相互に異なるstatusまたはerror typeとして識別でき、crashは可能な範囲で直前bufferを保持する |
| Classified input | secretのraw値と復元可能な表現はallowlistにかかわらず入らず、confidential contentとprivacy-sensitive dataは保存先に応じた明示的allowlist外の値が入らない。local recordingに必要なoperational identifierは保持でき、remote exportまたはpublic artifactでは不要な個人・host固有値が最小化される |
| 単純な決定的処理 | 適用除外条件を満たし、既存error contractだけで失敗箇所を一意に説明できる |
| Instrumented library | hostが保存先とconsumerを所有し、library単独ではSDK、exporterまたはglobal providerを構成しない |

実装方式に応じて、無効時と有効時のpublic behavior比較、保存失敗のfault injection、privacy fixture、async link、failure保持、
retention上限および削除経路を自動検証する。実環境でしか成立しない境界は、対象、証拠および未確認事項を明示する。

## 非目標

- すべてのrepositoryへのOTel SDK、OTLP、Collectorまたはcloud backendの一律導入
- すべてのfunctionやoperationのtrace化
- traces、metrics、logsおよびprofilesの全signal実装
- telemetryによるtyped error、exception、exit statusまたは利用者向けmessageの置換
- remote telemetryの既定送信
- stdout、stderrまたはUIへの大量のdiagnostic出力
- 記録済み観測による再現、回帰test、修正確認または反証の全面廃止
- compiler、test runner、VCS、sandboxおよびcoding agent自身を含むACI全体のwire format統一

## 派生guidance

AGENTS.mdやskillは本書の規則を重複して保持せず、本書を原典として参照し、workflowを開始する短いtriggerと停止条件だけを
定義する。少なくとも、開発workflowは実装前に適用判定と観測面設計を行い、問題調査workflowは再現前に保持済みrunを確認する。

本書からguidanceを派生させる変更は、本書の作成とは別の論理変更として、実際のforward testを伴って行う。

## 非規範参考資料

- [OpenTelemetry Specification Overview](https://opentelemetry.io/docs/specs/otel/overview/)
- [OpenTelemetry Trace API](https://opentelemetry.io/docs/specs/otel/trace/api/)
- [OpenTelemetry Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)
- [OpenTelemetry: Recording errors](https://opentelemetry.io/docs/specs/semconv/general/recording-errors/)
- [OpenTelemetry: Handling sensitive data](https://opentelemetry.io/docs/security/handling-sensitive-data/)
- [SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering](https://papers.neurips.cc/paper_files/paper/2024/file/5a7c947568c1b1328ccc5230172e1e7c-Paper-Conference.pdf)
