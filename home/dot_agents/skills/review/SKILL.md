---
name: review
description: 明示的に依頼された変更、またはsecurity、authority、破壊性、migration、compatibility、concurrency、resource lifecycle、releaseなどのclosed-set triggerに該当する変更を、fresh subagentで独立レビューする。
---

# Independent review

## Fix the review candidate

- `$develop-repository`がreview必須と判定した変更、または明示的なreview依頼だけを対象にする。Reviewのみの依頼では修正を行わない。
- 元要求を目的、observableな成功条件、hard constraint、確認済みの選択、検証済み・未検証の前提へ正規化する。[artifact profile and control domain](../../references/artifact-profile-and-control-domain.md) を読み、artifact profile、controlling subjects、protected assets、trust boundariesおよびoperational safetyを固定する。
- [data handling](../../references/data-handling.md) と、修正の場合は [failure oracle and causal verification](../../references/failure-oracle-and-causal-verification.md) を適用する。適用AGENTS、repository原典、比較対象、変更file、実装者の変更範囲および生の検証結果を特定する。
- Formatter、lint、型検査および軽量testを先に通し、exact diffをsnapshotとして固定する。Snapshot後はreviewと重い検証を並行できるが、結果を収集するまでdiffを変えない。

## Run a fresh reviewer

- 履歴を継承しない最低1体のread-only fresh subagentまたは同等の独立agentを直ちに起動する。同等とは、実装会話・推論を受け取らず、固定snapshotと中立な原材料だけから独立して判定できるagentをいう。利用不能なら自己reviewで代替せずblockedとする。
- Reviewerには元要求、中立なacceptance criteria、artifact/control-domain情報、working directory、比較対象、範囲、適用規約、current source、exact diffおよび生の検証結果だけを渡す。実装計画、設計の正当化、途中推論、疑わしい箇所または期待する指摘は渡さない。
- Terminal reviewerとして再委譲せず1 turnで範囲全体を調査し、日本語のactionableな指摘だけを一つの最終報告へ集約させる。規模とclosed-set riskに応じて追加reviewerを使う。

- 成果物を対象読者の立場で読み、用途に必要な情報の不足と、不要な情報による認知負荷の両方を確認する。READMEなどの文書、code commentおよびPR説明では、変更された説明のまとまりを既存記述も含めて確認し、実装会話を知らない読者にも必要かを判断する。不要な経緯・比較・念押し・重複・詳細は削除・統合を指摘し、必要な比較、制約および理由は保持する。経緯を伝える報告・記録はその用途で判断し、無関係な箇所の全面整理は求めない。

各指摘には重大度、fileとlineまたは説明の位置、影響、根拠、および最小修正を含める。挙動の指摘には到達可能な失敗条件、関係するcontrolまたはoperational-safety条件、source・test上の根拠を示す。読者向け情報の指摘には対象読者、用途および理解・操作・判断への具体的な不足または負荷を示し、実行時障害を要件にしない。Data findingは値の能力または明示contractと実際のsinkを示す。型や既存validationで排除済みの問題、根拠のない将来懸念、style選好、確認済みtrade-offの再審議は除く。読者と用途を根拠とする情報の過不足はstyle選好と区別する。

不具合修正では、変更後も元oracleがfailする反例と、変更で新しく到達するdownstream state、意味変換、retry、re-entryおよび逆操作を確認する。Cross-processまたはresource変更では、境界両側のdata/control flow、failure、timeout、signal、cleanup ownershipおよび残留状態を追う。

Program経路のreviewでは [program observability contract](../../references/agent-computer-interface-observability.md) を読み適用判定する。対象なら実装者のログ項目一覧だけに依存せず、変更経路と再利用される共有境界のsourceから入力・重要な判断・処理境界を追い、記録の実装と通常runの保持済み証拠に照合してDiagnostic sufficiencyとconformanceを確認する。正常終了・無処理や同じ終了結果になる別経路も調べ、漏えいと過剰な秘匿の両方にdata handlingを適用する。到達可能な状況で何と何を区別できず、どの情報が欠けるかを示せる不足は契約上の欠陥として指摘する。必要なrun証拠がなければ充足と断定せず未検証として報告する。診断上の効果を説明できない詳細記録は要求せず、適用除外の条件も確認する。

## Adjudicate findings

- Reviewerの最終報告まで修正を始めない。Main agentが各候補をsource、型、実行経路、validationおよびtestで検証する。
- 現行要求から結果が一意で、依頼範囲内かつ新しいdependency、authorityまたはmigrationなしに局所修正できる欠陥は自動対応する。誤検出、重複、到達不能、既存保証済み、styleまたは要求外generalizationは棄却する。
- 公開contract、scope、設計、継続コスト、新規dependency、authorityまたはmigrationに複数の妥当な選択が残る指摘だけをユーザー判断とし、全結果収集後に根拠、影響、規模および推奨を一度に示す。
- Spikeの現目的に影響せずdurable化でだけ成立する懸念はpromotion conditionとして既存planまたはhandoffへ集約し、現在の修正へ昇格させない。

## Close the review

- 修正後は影響した検証を再実行してexact diffを固定する。文言・format・決定的生成結果だけでbehaviorやinterfaceを変えないdeltaは直接確認できる。その他は、同じcontract内の局所修正なら元reviewerへdelta reviewを、境界や設計を変えた修正または元reviewer不在なら別fresh reviewerへfull reviewを依頼する。
- Actionableな指摘がなく、必要な検証が成功し、review済みsnapshotと確定対象が一致した時点だけ完了する。Reviewer未完了、必要な判断・権限不足、またはsnapshot driftはblockerとする。
