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

各指摘には重大度、fileとline、影響する挙動、到達可能な失敗条件、controlまたはoperational-safety条件、source・test上の根拠、および最小修正を含める。Data findingは値の能力または明示contractと実際のsinkを示す。型や既存validationで排除済みの問題、根拠のない将来懸念、style選好、確認済みtrade-offの再審議は除く。

不具合修正では、変更後も元oracleがfailする反例と、変更で新しく到達するdownstream state、意味変換、retry、re-entryおよび逆操作を確認する。Cross-processまたはresource変更では、境界両側のdata/control flow、failure、timeout、signal、cleanup ownershipおよび残留状態を追う。

## Adjudicate findings

- Reviewerの最終報告まで修正を始めない。Main agentが各候補をsource、型、実行経路、validationおよびtestで検証する。
- 現行要求から結果が一意で、依頼範囲内かつ新しいdependency、authorityまたはmigrationなしに局所修正できる欠陥は自動対応する。誤検出、重複、到達不能、既存保証済み、styleまたは要求外generalizationは棄却する。
- 公開contract、scope、設計、継続コスト、新規dependency、authorityまたはmigrationに複数の妥当な選択が残る指摘だけをユーザー判断とし、全結果収集後に根拠、影響、規模および推奨を一度に示す。
- Spikeの現目的に影響せずdurable化でだけ成立する懸念はpromotion conditionとして既存planまたはhandoffへ集約し、現在の修正へ昇格させない。

## Close the review

- 修正後は影響した検証を再実行してexact diffを固定する。文言・format・決定的生成結果だけでbehaviorやinterfaceを変えないdeltaは直接確認できる。その他は、同じcontract内の局所修正なら元reviewerへdelta reviewを、境界や設計を変えた修正または元reviewer不在なら別fresh reviewerへfull reviewを依頼する。
- Actionableな指摘がなく、必要な検証が成功し、review済みsnapshotと確定対象が一致した時点だけ完了する。Reviewer未完了、必要な判断・権限不足、またはsnapshot driftはblockerとする。
