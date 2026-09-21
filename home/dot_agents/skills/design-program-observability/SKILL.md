---
name: design-program-observability
description: 非自明な開発対象programの経路について、実装前に観測面の適用判定、意味契約、recording、privacyおよびconformanceを設計する。外部境界、状態変更、非同期・並行、複数段階または再現困難な経路を追加・変更するとき、および不具合修正前に観測面を追加・修復するときに使用する。
---

# Design program observability

## Apply the canonical contract

- [Program observability contract](../../references/agent-computer-interface-observability.md) をすべて読み、repository固有方針があれば優先する。同契約が適用を要求する経路だけを対象にし、形式や実装量だけで判断しない。
- [Data handling](../../references/data-handling.md) と [failure oracle and causal verification](../../references/failure-oracle-and-causal-verification.md) を必要なclassificationと完了判定に使い、ここで定義を再作成しない。

## Inspect before designing

- 結果面、操作面、telemetry、structured log、state query、artifact、recording、retention、利用者control、およびapplication/library ownershipをsourceとruntimeから確認する。
- 不具合修正では `$investigate-problem` が固定したoracle、保持済みrun、記録完全性および未確認boundaryを入力にする。既存証拠で原因と修正確認に必要な段階を識別できるなら新しいinstrumentationを追加しない。

## Define the smallest observation surface

- 利用者操作に対応するDiagnostic RunとResource、およびfailureを区別する最小のOperation、Event、Status、Error Type、Context・Link、Artifactを定める。
- 結果面、操作面、out-of-bandな観測面とdiagnostic IDを分離する。通常code pathを観測し、public stdout、stderr、API responseまたはUIをagent向けtransportにしない。
- Instrumentationと有界local recordingを既定有効・opt-out可能、remote exportを既定無効・明示opt-inとする。正常runの猶予保持、failure優先保持、retention、削除、safe export、recording healthおよびresource上限を定める。
- Attributeとartifactをsource allowlistで最小化し、観測failureの非干渉性と記録完全性を定める。Libraryはhostのprovider、contextまたはsinkを使い、SDK、global provider、exporterまたは保存先を所有しない。
- 既存標準面、runtimeのidiomatic機構、OTel互換API、小さなdiagnostic sinkの順で最小実装を選ぶ。OTel SDK、OTLPまたはCollector自体を目的にせず、新規dependencyは`$develop-repository`の事前承認gateへ戻す。

## Implement and verify

- 観測不足ならproduct fixより先の論理変更として最小経路を実装し、同じfailureで必要な段階と完全性を取得してから修正する。新機能では結果・操作面と同じ最初の実装に含める。
- Operation ownerがcauseを保持したfailureを一度記録し、handled failure、retry、cancel、timeoutおよびfinal resultを区別する。
- 変更経路に到達可能なconformance scenarioだけを選び、有効・無効時のpublic behavior、local保持、remote未送信、recording failure、partial・dropped、privacy fixture、retention、削除およびownershipを比例的に検証する。

## Hand back or stop

- 適用除外、既存面で十分、実装・検証済み、またはblockerのいずれかを、証拠、選んだscenarioおよび残るboundaryとともに`$develop-repository`へ返す。
- Repository方針との衝突、新規dependency、またはsafe allowlist・retention・利用者controlを決めるauthority不足ではproduct実装へ進まず、必要な決定と推奨を示して停止する。
