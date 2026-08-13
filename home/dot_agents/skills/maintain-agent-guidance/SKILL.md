---
name: maintain-agent-guidance
description: 現在タスクまたは複数sessionとmemoryからcandidate learningを監査し、AGENTS.md、global guidance、skill、scriptまたはautomationへの永続化を検証・提案する。
---

# Candidate Learning

- Codex memoryをknowledge baseやpolicyではなく、過去sessionから生成された反証可能なdescriptiveな仮説cacheとして扱う。memory単独からnormativeな規則へ昇格させない。
- session logを一次証拠として扱うが、成功や失敗の観測だけで因果関係を確定しない。source、testまたはlive observationで検証し、現在事実とnormativeな規則を区別する。
- AGENTS.md、global guidance、skill、scriptおよびautomationは、人間が採用したnormativeな規則の原典とする。memoryと衝突する場合は行動規範としてこれらを優先し、memoryは原典の陳腐化を再検証するtriggerとしてのみ使う。
- current-task auditまたはcross-session auditでcontradictedまたは陳腐化したmemoryを検出しても、生成されたmemory fileを直接編集しない。読み取り専用の候補として報告し、人間が別途明示した場合だけ利用可能なmemory controlで訂正または忘却する。
- 検証失敗の原因が確定した時点、論理変更の確定前およびタスク完了時をcheckpointとする。実装結果、失敗した操作、成功した操作、ユーザーによる訂正、不要な往復、手動で促された処理および既存規則が実行されなかった事例を対等なcandidate learningとして監査する。
- 依頼範囲内で修正できる決定的な欠陥は永続化候補へ延期せず、source、test、task、build processまたは実行環境の最も近い原典で通常の開発workflowとして解消する。
- 依頼範囲内の原典で通常の開発workflowとして解消する決定的な欠陥を除き、永続化候補は保存先にかかわらず自動反映しない。保存先、根拠、理由および具体的な追加・修正文を提示し、承認後に元の成果物とは別の論理変更として確定する。
- 最終報告では、checkpointで解消できなかった横断的または非決定的な候補だけを提示する。
- 失敗履歴や一時的な環境情報をそのまま残さず、適用条件、正しい手順および禁止事項へ一般化する。
- 候補を提示する前に振り返り手順自体への訂正も一度だけ同じ基準で評価し、再帰的な振り返りは行わない。

### Validation

candidate learningは次の順序で評価する。

1. 成功または失敗の記録をそのまま規則化せず、そこから推定した一般則を仮説として明示する。
2. 原因をsource、test harness、taskまたはbuild process、workflow trigger、実行環境、一時的外因、agent操作ミス、memoryの陳腐化または未確定のいずれかへ帰属する。ユーザーのnormativeな選択は因果問題でないため`not applicable: normative choice`とする。
3. 同じ操作の成功・失敗、別repository、別version、別権限または別入力を反証・対照例として探す。成功例でもその操作が必要条件だったかを検証する。
4. 適用範囲を個人全体、repository、OS、version、toolまたは単一taskのいずれかに限定する。
5. source、test、現行guidance、skillまたはscriptですでに解消済みでないことを確認する。
6. `promote`、`retain as hypothesis`、`needs validation`、`contradicted`、`already resolved`または`one-off/no persistence`のいずれかへ分類する。

- `retain as hypothesis`は、現時点では一般化できず、追加検証を計画する価値や具体的な検証経路も不足する仮説に使う。
- `needs validation`は、汎化する価値または影響があり、次に実行する具体的な検証、反証条件および停止条件を定義できる仮説に使う。
- `already resolved`は、仮説が妥当でも最も近いsource、test、guidance、skillまたはscriptですでに解消され、追加の永続化が不要な場合に使う。

- 通常のworkflow規則またはtool選好の昇格には、独立した複数事例、または再現testと反証例を必要とする。
- ユーザーが明示した個人的な好みは、衝突と適用範囲を確認すれば単一発言でもglobal guidance候補にできる。
- 権限、安全性または破壊的操作に関する明示policyは、被害が大きい場合に単一事例でも候補にできる。
- repository固有の決定的仕様は、sourceまたはtestで確認できれば事例数を要求しない。
- repository固有の仕様がsourceまたはtestで正しく保有され、agentの行動を変える追加条件もない場合は`already resolved`とする。sourceから容易に発見できないAI専用の行動条件が残る場合だけ、近いAGENTS.mdへの昇格を検討する。
- `promote`または`needs validation`には、期待する正例、誤った一般化を検出する負例、および昇格を中止する停止条件を含むforward testを定義する。

### Cross-session Audit

- 明示的に複数sessionのmemoryやcandidate learningの監査を依頼されたときだけ、`scripts/collect-session-evidence.ts`を使って完了済みroot sessionを収集する。現在の監査thread、subagent、未完了sessionおよび重複session IDは対象にしない。
- source stateまたは実行権限のないcopyからは、`mise exec -- deno run --allow-env=CODEX_HOME,HOME,USERPROFILE --allow-read <skill-dir>/scripts/collect-session-evidence.ts ...`として実行する。chezmoiで適用済みのexecutable targetは直接実行してもよい。
- 対象範囲と期間は依頼に従う。指定がなければ、全local repositoryの直近7日間の開発root sessionを古い順に最大25件評価し、残件を報告する。session内のいずれかのturnでrepository変更、実装計画、VCS確定またはPRが依頼・実行されたらsession全体を開発sessionとする。read-onlyの外部service参照だけのsession、一般相談および監査自体は含めない。
- extractorの`--limit`はroot sessionの収集batch数であり、開発sessionの判定は監査側で行う。batch内の開発sessionが25件未満で`remainingSessions`が残る場合は、最後に読んだ`startedAt`を次の`--after`にして続け、25件または対象期間の終端で停止する。
- memoryは候補発見のindexとしてのみ読み、claimに対応するsession logまたはその他の一次証拠へ遡れなければ昇格対象にしない。session extractorの`parseWarnings`、`redactedMessages`、`truncatedMessages`または`omittedMessages`が1以上の証拠は不完全とし、そのsessionだけを根拠とした昇格を禁止する。欠落範囲を狭いsecret-safeなqueryで再抽出するか、source、testまたはlive observationで補完できた場合だけ評価を続ける。
- 監査はread-onlyで行い、memory、repository、issueまたはVCSを更新しない。候補の採用後に、別の開発turnで論理変更として反映する。
- coverage期間、評価したsession IDおよび残件を報告したうえで、candidate learningを最大5件まで提示する。各候補にID、仮説、由来、一次証拠、反証・対照例、原因帰属と確信度、適用範囲、現行guidanceとの関係、推奨判断と保存先、必要なforward testおよび誤った一般化で失われる探索経路を示す。
- 昇格できないmemory由来候補、`already resolved`の候補、一時的外因および単発の実装経緯は昇格候補へ含めず、棄却理由別の件数だけを報告する。候補がなければcoverageと棄却集計だけを簡潔に報告する。

### Routing

- 全タスクに共通する個人方針はglobal
  guidance、リポジトリ固有のAI向け規約、コマンドおよび検証条件は適用範囲に最も近い `AGENTS.md`
  の候補にする。
- 学びごとにsourceまたはdocumentation、test、taskまたはbuild process、実行環境、repo `AGENTS.md`、global guidance、skill、scriptまたはautomation、永続化不要のいずれかを原典として選ぶ。
- 人間にも重要な仕様、設計および業務知識はsource、documentationまたは外部システムを原典とし、`AGENTS.md`
  へ重複させない。
- 単一環境の決定的な反復処理はscript、taskまたはautomationへ移し、guidanceにはtriggerと入口だけを置く。
- 2つ以上の実例で入出力、手順および失敗条件を確認した汎用ワークフローは、personal global
  skillとして提案する。候補には目的、trigger、入出力、手順、失敗条件、停止条件、検証方法および保存先を示す。
- skillには汎用手順だけを置き、固有値は各原典から読み取る。承認後に作成し、配布要件が生じた場合だけplugin化を検討する。
- 他者のリポジトリや外部workspaceでは既存方針と権限範囲を優先し、適合する場合だけ永続化を提案する。

### Maintenance

- 各反映提案で対象ファイル全体を監査し、新規追記より既存指示の統合、置換、簡略化および削除を優先する。
- 既存規則があったのに実行されなかった場合は同じ規則を重複させない。agentの行動を開始させるtriggerは実際のworkflowを定義するskillの入口または終了条件へ組み込み、単一環境で機械的に強制できる処理は最も近いtask、scriptまたはautomationへ移す。
- 行動を変えない情報、原典から容易に発見できる事実および一度限りの判断はguidanceへ追加しない。
- 同じ規則は一度だけ記載し、詳細な手順、例および参考資料はskill、scriptまたはdocumentationへ移す。
- 規則を定義するskill自体が起動されなかった場合は、到達不能なskill本文へtriggerを追加しない。個人またはrepository全体に適用するなら常に読み込まれるAGENTS.md、特定workflowだけなら上位skillまたはdispatcher、機械的に判定できるならtask、scriptまたはautomationをtriggerのownerにする。
- 重複、矛盾、陳腐化、長い手順またはスコープ不明な規則を検出した場合だけ、全体的な棚卸しを提案する。固定の長さではなく情報密度と適用範囲で判断する。
