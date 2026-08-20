---
name: design-program-observability
description: 非自明な開発対象programの経路について、実装前に観測面の適用判定、意味契約、recording、privacyおよびconformanceを設計する。外部境界、状態変更、非同期・並行、複数段階または再現困難な経路を追加・変更するとき、および不具合修正前に観測面を追加・修復するときに使用する。
---

# Design Program Observability

## Read the contract

- [Agent-Computer Interface向けプログラム観測契約](../../references/agent-computer-interface-observability.md)をすべて読み、
  対象repository固有の方針があれば優先する。
- 外部境界、状態変更、非同期・並行、複数段階または再現困難性のいずれかがある経路を適用対象とする。除外する場合は、
  短く同期的かつ決定的で、既存error contractからfailureを一意に識別でき、安全かつ安価に再実行できることを確認する。
- CLI、GUI、serviceまたはlibraryという形式だけで適用可否を決めない。

## Inspect the existing observation surface

- 対象経路の結果面、操作面、既存のtelemetry、structured log、state query、artifact、recording、retentionおよび利用者controlを
  sourceと実行時状態から確認する。
- applicationとlibraryのownershipを特定する。libraryではSDK、global provider、exporterまたは保存先を所有せず、hostから
  与えられるprovider、contextまたはdiagnostic sinkを使う。
- 不具合修正では、`investigate-problem`が確認した保持済みrun、failure oracle、記録完全性および未確認boundaryを入力とする。
  既存証拠で原因と修正確認に必要なfailure段階を識別できるなら、新しいinstrumentationを追加しない。

## Fix the observation contract before implementation

- 利用者の操作またはrequestに対応するDiagnostic RunとResourceを定める。
- 異なるfailureを区別する最小のOperation、Event、Status、安定したError Type、Context・LinkおよびArtifactを定める。
- publicなstdout、stderr、API responseまたはUIへagent向け診断情報を混在させず、out-of-bandな観測面と必要なdiagnostic IDを
  定める。
- instrumentationと有界なlocal recordingを既定有効、利用者によるopt-outを可能、remote exportを既定無効かつ明示opt-inに
  する。正常runの猶予保持、failure優先保持、retention上限、削除、safe exportおよびrecording healthを定める。
- attributeとartifactはsource側のallowlistで最小化する。credential類のraw値または復元可能な表現を禁止し、記録完全性、
  degradation、resource上限および観測面failureの非干渉性を定める。

## Select the smallest implementation

- 既存の標準的な観測面、対象runtimeのidiomaticな機構、OTel互換のAPIまたは小さなdiagnostic sinkの順に、意味契約を満たす
  最小の実装を選ぶ。OTelの語彙を優先できるが、OTel SDK、OTLPまたはCollectorを目的として導入しない。
- 新規dependencyが必要なら、`develop-repository`のdependency gateに従って必要性、主な代替、保守・security・配布への影響を
  示し、追加前に承認を求める。承認前に独自実装やstdout/stderrへのfallbackで迂回しない。
- 既存programでは、今回変更する経路と再利用される共有境界だけを準拠させる。依頼なしにprogram全体を移行しない。

## Implement in causal order

- 既存failureを十分に観測できない場合は、最小観測経路をproduct fixより先の論理変更として実装し、同じfailureで必要な
  operation、error type、関連状態および記録完全性を取得できることを確認してから修正へ進む。
- 新規featureでは、観測面を結果面と操作面と同じ最初の実装へ含め、通常動作と同じcode pathをinstrumentする。
- error causeを保持し、operationを所有する境界でfailureを一度記録する。handled failure、retry、cancellationおよび最終結果を
  区別する。

## Verify conformance

- 変更経路に到達可能なconformance scenarioだけを選び、観測有効・無効時のpublic behavior、local保持、remote未送信、
  recording/export failure、partial・dropped、privacy fixture、retention上限、削除およびlibrary ownershipを比例的に検証する。
- programがfailureと判定したrunだけでなく、success判定後に利用者がfailureと判断できるrunの猶予保持も確認する。
- 実環境でしか確認できないboundaryは、確認済み範囲、未確認事項、理由および必要なlive検証を報告する。

## Stop or hand back

- 対象repositoryの方針が本契約と衝突する、新規dependencyの承認が必要、または安全なallowlist・保持・利用者controlを決める
  authorityがない場合は、product implementationへ進まず、決定が必要な点と推奨案を示して停止する。
- 適用除外、既存観測面で十分、観測面を実装・検証済み、またはblockerを特定済みのいずれかになったら、判断、証拠、選択した
  conformance scenarioおよび残存boundaryを`develop-repository`へ引き渡す。
