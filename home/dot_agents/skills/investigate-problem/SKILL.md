---
name: investigate-problem
description: 不具合、障害、エラーまたは期待と異なる振る舞いを、保持済みの観測証拠、必要な再現および反証から診断する。ソフトウェア、設定または実行環境の問題調査、原因究明または修正前調査を依頼されたときに使用する。
---

# Problem investigation

## Fix the question and evidence boundary

- 期待結果、症状、再現条件、影響、および調査だけか修正も含むかを確定する。修正依頼がなければread-only観測に限る。
- [Failure oracle and causal verification](../../references/failure-oracle-and-causal-verification.md) を読み、利用者が判断する最終状態をoracleとして固定する。提示された原因や修正案、model知識、memoryおよび類似事例は反証可能なpriorとする。
- 対象programが観測面を持つ場合は [program observability contract](../../references/agent-computer-interface-observability.md) を読み、再現前に該当runを探す。Run ID、時刻、version、runtime、environmentと操作を対応付け、operation tree、status、error type、event、link、artifactおよび完全性を確認する。Partial、droppedまたはdegradedを事象の不在とみなさない。
- 症状環境、観測環境および結果が成立すべき環境を分ける。Sandbox内だけの不存在、接続失敗または権限拒否を対象環境の事実にせず、許可された対象相当環境または正確な利用者向け観測で切り分ける。

## Choose discriminating observations

- User operation、physical input、entry path、configuration、runtime、environmentおよびdownstream stateを横断して未検証前提を候補にし、高signalな証拠で除外済みの層は飛ばす。
- 次の観測を仮説の反証力と総コストで順位付けする。総コストにはユーザーの時間、操作・認知負担、downtime、状態変更、risk、復旧およびtool時間を含める。短い利用者確認が深いagent調査より安ければ、区別する仮説、操作、分岐、時間およびriskを示して先に依頼できる。
- 高コストなreboot、install、設定変更、別OS、firmware、分解または長時間再現は、より安い識別手段がなく、結果で次の行動が変わる場合だけ提案する。数分超の操作や識別価値が低い探索へ進む前に、証拠、残る仮説、利益、負担およびriskを示して選択を戻す。
- 予想外の観測、仮説が狭まらない反復、または新しい視点があれば、既存説明へ継ぎ足さず仮説集合を組み直す。

## Test hypotheses

- 観測、仮説、推論およびunknownを分け、有力候補ごとに到達可能な失敗条件と反証観測を定める。
- 再現ではbaseline、変更する一要因、取得値および反証条件を決める。状態変更が必要ならauthorityと影響を示して承認を得る。
- 症状の場所と原因を区別し、workaroundによるpassを原因除去とみなさない。恒久化せず、明示依頼された一時mitigationだけを診断と分けて提案する。
- 修正前のfailureと同じbaselineの最終oracleが修正後にpassすることを確認する。異なる条件のsuccessは未確認boundaryとして扱う。

## Conclude or hand off

- Root causeを確定した場合は破られたinvariantからoracleまでの因果連鎖を示す。未確定なら断定せず、証拠、除外候補、残る仮説、確信度、追加観測、riskおよび停止理由を報告する。
- 修正も依頼された場合は、原因を除く最小変更面とoracleを`$develop-repository`へ渡す。観測不足ならproduct fixより先に`$design-program-observability`へ渡す。
