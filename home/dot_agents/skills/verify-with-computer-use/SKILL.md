---
name: verify-with-computer-use
description: CLIによる検証後も残るGUIの表示または操作結果を、現在のsessionで利用可能なComputer Use toolにより確認する。リポジトリ開発で利用者向けGUIの最終結果をagentが直接観測する必要がある場合に使用し、toolが利用できなければ設定や導入を行わず、人間向け確認手順へ移譲する。
---

# Computer Useによる確認

## 未確認範囲を定める

- 元の要求、acceptance criteria、対象buildおよびCLIで得た検証証拠を確認する。
- GUIでしか確認できない表示または操作結果だけを特定し、安価な検証を重複して実行しない。

## Toolの利用可否を確認する

- 現在のsessionに公開されたtoolを調べ、対象GUIの表示取得、必要な入力操作および操作後の状態観測を完了できるか確認する。
- documentation、設定、実行fileまたは過去sessionでの利用実績だけから、toolを利用可能と判断しない。
- 必要なtoolが不足、無効または到達不能なら、Computer Useをskipする。tool、plugin、MCP serverのinstall、設定、有効化、接続またはloginを行わない。

## 利用可能な場合に確認する

- application固有の設定・データパス、test profileまたはその他の隔離環境を使用する。
- acceptance criteriaを判定できる最小のflowだけを操作し、結果を画面またはtoolが返す画像として観測する。
- ユーザーの実desktop、通常profile、実data、実accountまたは実serviceが必要なら、対象、操作、想定される状態変更および復旧方法を示して事前承認を求める。
- 実行したflow、観測結果、取得した証拠および残存する未確認事項を報告する。

## 利用できない場合は人間へ移譲する

- Computer Useを実行せず、利用できなかった機能と理由を明示する。利用不能だけを実装完了のblockerにしない。
- 人間が確認できるよう、次を具体的に報告する。
  - 対象application、build、revisionおよび起動方法
  - 隔離用の設定、dataおよび事前準備
  - 実行する操作手順
  - 各手順で期待する表示または状態
  - agentが既に確認した証拠と、残るrisk
- GUI結果を未確認として明示し、人間による確認へ移譲する。
