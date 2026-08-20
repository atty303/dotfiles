---
name: investigate-problem
description: 不具合、障害、エラーまたは期待と異なる振る舞いを、保持済みの観測証拠、必要な再現および反証から診断する。ソフトウェア、設定または実行環境の問題調査、原因究明または修正前調査を依頼されたときに使用する。
---

# Problem Investigation

## Scope the investigation

- 期待する結果、実際の症状、再現条件および影響を確定する。
- 修正前に、利用者が失敗と判断した最終状態を成功・失敗のoracleとして固定する。redirect、title、request開始または初期renderなどの途中状態や、異なる条件での成功をoracleの代用にしない。
- 対象programが観測面を持つ場合は、[program観測契約](../../references/agent-computer-interface-observability.md)を
  すべて読み、再現より先に報告されたrunを探す。run ID、発生時刻、program version、runtime、environmentおよび利用者操作を
  対応付け、resource、operation tree、status、error type、event、linkおよびartifactを確認する。
- runの完全性が`partial`または`dropped`、あるいはrecording subsystemがdegradedなら、欠落を事象の不在として扱わない。
  保存済みrunで判断できないboundaryと、追加で必要な観測を明示する。
- 症状が報告された環境、各観測を実行する環境および期待結果が成立すべき対象環境を区別する。Codexの実行環境はsandboxであり得る一方、ユーザーの指示や報告が同じ制約下にあるとは仮定しない。
- filesystem、network、socket、device、credential、GUI sessionその他の環境境界に関係する失敗は、観測した環境を証拠へ付記する。Codex sandboxだけで再現した失敗を対象環境の不具合と断定せず、許可された対象相当環境での再観測、またはユーザーが実行できる正確な観測手順によって切り分ける。
- 原因調査と修正のどちらを依頼されているかを区別する。修正まで依頼されていなければ、読み取り専用かつ状態を変更しない観測だけを行う。
- 適用されるguidance、source、設定、ログおよび履歴から発見できる事実を先に調べ、発見できない意図または欠落情報だけを確認する。

## Build and test hypotheses

- 観測事実、仮説、推論および未確認事項を区別する。
- 不確実性または競合する説明がある場合は、有力な原因候補を複数検討し、到達可能な失敗条件と各仮説を反証できる観測を定める。
- 保持済みrunと状態を変更しない追加観測を優先し、それらで判断できないboundaryだけを再現する。報告されたbrowser、runtime、
  version、entry path、inputおよびtimingのうち結果へ影響し得る条件を再現baselineへ記録する。再現に状態変更が必要な場合は
  実行せず、必要性と影響を示して追加の承認を求める。
- 症状が現れた場所と原因を区別し、破られた不変条件から症状までの因果連鎖を確認する。
- 仮説比較ではbaselineから一度に一要因だけを変え、失敗段階を観測する前に恒久修正を積み重ねない。修正も依頼されている場合は、修正前の失敗を記録し、同じbaselineの最終oracleがfailからpassへ変わることを確認する。修正前後を同じbaselineで直接比較できない、または別要因の混入を除外できない状態でroot causeを断定する場合だけ、安全かつ検証コストに比例する範囲で、変更を外すか失敗条件を戻した対照によりpassからfailへ戻ることも確認する。対象条件を実行できなければ、異なる条件での成功を修正確認とせず、未確認boundaryとして報告する。

## Conclude or stop

- root causeを特定した場合は、破られた不変条件から症状までの因果連鎖を示す。
- 証拠が足りない場合は断定せず、未確定の候補と必要な追加観測を示す。
- いずれの場合も、観測証拠、除外した有力仮説、影響範囲、現在の確信度、未確認事項、残存リスクおよび調査を終了または停止した理由を報告する。
- 修正も依頼されている場合は、原因を取り除く最小の変更面を示し、対象リポジトリの`develop-repository` workflowに引き渡す。
  観測面の追加または修復が必要なら、product fixより先に`design-program-observability`を使用するよう明示する。
