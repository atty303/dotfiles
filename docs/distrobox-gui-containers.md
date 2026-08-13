# DistroboxによるGUI applicationのコンテナ化

Status: Living reference
Last verified: 2026-08-13

## 目的

この文書は、このdotfilesでGUI applicationをDistroboxへ置くときの設計原則と、host desktopへ統合するために
追加した設定の意図を記録する。Distroboxやcontainer imageのversion、実際のmount、導入packageなど機械が利用する
値はmanifestとimageを原典とし、ここには複製しない。

記述の確度は次の語で区別する。

- **Upstream**: Distrobox、Podmanまたは各applicationの一次資料が定める挙動。
- **構成確認**: このrepositoryの設定とscriptから確認した設計。
- **Live確認**: 稼働中のhostとcontainerを読み取り観測して確認した挙動。確認日を上記に記す。
- **推論**: upstream、構成またはlive観測を組み合わせて導いた意図、影響または制約。
- **未確認**: 必要性または実現方法をまだ実環境で確認していない事項。

本文中の無印の記述はこの文書が定める設計原則である。外部仕様、現在の実装、live状態またはそこから導いた判断を
述べる箇所には上記のラベルを付ける。

## 原則

### Containerはsecurity boundaryではない

Distroboxの目的は、別distributionのrootfsとpackage ecosystemをhostへ持ち込むことである。applicationを隔離したり、
信頼できないcodeからhostを守ったりするためには使わない。Distrobox自身も、isolationやsandboxingではなくhostとの密な
統合を目的とし、HOME、device、socketなどへ広くアクセスできると明記している。

rootless Podmanはrootful containerより権限を制限するが、この用途で信頼境界を作るものではない。HOMEやsession busへ
到達できるprocessは、user本人と同じデータやserviceを操作できる。隔離が要件ならFlatpakのpermission modelや、通常の
Podman containerなど、隔離を設計目的に含む別の仕組みを選ぶ。

### Host integrationを最大化する

containerが所有するのは、主にapplication binary、library、distribution固有のpackageとその依存関係である。それ以外の
desktop資源は、可能な限りhostの既存sessionを共有する。

| 資源 | 原則 | 主な境界・注意点 |
| --- | --- | --- |
| HOMEと設定 | hostと共有し、host/containerで同じuser stateを使う | 隔離性はなく、異なるversionが同じ設定を読む可能性がある |
| Wayland/X11 | hostのdisplay socketへ接続する | socketのmountだけでなく、対応する環境変数と認証情報も必要 |
| audio/video | hostのPipeWire/PulseAudio socketを使う | host側daemonとcontainer側client libraryの互換性に依存する |
| GPU/input/device | host kernel、driver、`/dev`、udev情報を使う | kernel moduleやhost driverをcontainerから置き換えることはできない |
| D-Bus/logind | hostのsession busと、必要な場合だけsystem busを使う | system busの公開は権限を増やす。接続後の認可はhost policyに従う |
| PAM/polkit | hostに残す | credential、PAM stack、認証deviceをcontainerへ複製しない |
| application起動 | host applicationはhostで、container applicationはcontainerで実行する | command名だけでは実行側が曖昧になるため、明示的なbridgeを使う |
| desktop metadata | launcherから必要なentryやiconをhostへexportする | binary exportだけではman page、completion、session entryなどは出ない |

**Upstream:** Distrobox標準の統合は、HOME、Wayland/X11、audio、network、device、D-Bus、SSH agentなどをcontainerへ見せる。
`distrobox-export` はcontainer内のapplicationやbinaryをhostから起動するwrapperにし、`distrobox-host-exec` は逆に
containerからhost commandを実行する。この双方向bridgeを、実行主体を曖昧にするためではなく、hostとcontainerの責務を
保ったまま一つのdesktop sessionとして使うために利用する。

## Scrollで追加している統合

Scrollは単体GUI applicationより統合範囲が広い。Wayland compositor自体はcontainerのrootfsから実行する一方、login
sessionとsystemd user manager、認証、host applicationはhostに残す。現在の原典は
[`scroll.ini`](../home/dot_config/distrobox/assemble/scroll.ini)、
[`scroll/config`](../home/dot_config/scroll/config)、および
[`chezmoi-distrobox-scroll-update`](../home/dot_local/libexec/executable_chezmoi-distrobox-scroll-update)である。

### Display、IPC、audio

**Live確認:** 稼働中のScroll containerでは、hostの`/run/user/1000`が共有され、Wayland display、session D-Bus、
PipeWire、PulseAudio、Scroll IPCの各socketへ到達できた。`DISPLAY`、`WAYLAND_DISPLAY`、`XDG_RUNTIME_DIR`、
`DBUS_SESSION_BUS_ADDRESS`、`SWAYSOCK`、`I3SOCK`、`SCROLLSOCK`もcontainer processへ渡っていた。

**構成確認:** `scroll.ini`はX11 socketを明示的にmountしている。
**推論:** これはScroll sessionのXwaylandが公開するX11 socketへ、container内のX11 clientが接続できるようにするためである。
system D-Bus socketのmountはScrollがhostのlogindへ接続するために追加している。これは新しいlogindをcontainer内に立てる
構成ではなく、host serviceへ接続する構成である。

**構成確認:** `scroll.ini`は`--userns keep-id:size=65534`と`run.oci.keep_original_groups=0`を指定している。
**推論:** これらはrootless Podman上のUID/GID mappingと補助groupの
扱いを成立させるためのruntime設定であり、security isolationを強める設定ではない。NVIDIA variantはhost GPU stackとの
追加統合が必要なmachineだけで選ぶ。

### Hostとcontainerをまたぐcommand

**構成確認:** `scroll`、`scrollmsg`、`scrollnag`、`scrollbar`はbinary exportされ、hostのUWSM serviceからcontainer版を起動できる。
**Upstream:** binary export wrapperはhostからは`distrobox enter`の入口、対象container内では実binaryへの入口として振る舞う。
**Live確認:** Scrollのexport wrapperは共有HOME上に配置されていた。

**構成確認:** 逆方向では、`uwsm`と`vicinae`を`host-exec`へsymlinkしている。
**推論:** Scrollの設定に現れるこれらのcommandをhostで実行し、host systemd user managerとhost applicationをcontainer側へ
複製しないためである。単なるPATH共有では、同名binaryがどちらのrootfsで動くべきかを表せないため、bridgeを明示する。

**構成確認:** Scrollは起動後に`uwsm finalize SWAYSOCK I3SOCK SCROLLSOCK ...`を実行する。PAMとpolkitはcontainerへ
持ち込まず、host session targetからhostのagentを起動する。
**推論:** `uwsm finalize`はcompositorが生成したIPC socketなどの値をhostのUWSM/systemd user sessionへ確定し、
その後host側で起動するapplicationやserviceも同じScroll sessionへ接続できるようにする。

### Session lifecycleと更新

**Live確認:** Scrollはhostの`wayland-wm@scroll.service`としてactiveであり、hostの`uwsm aux exec`がexport済みScroll
wrapperを起動していた。**推論:** compositor processをcontainer内のinit systemへ所有させず、desktop sessionの生存期間をhost
systemdへ揃える設計である。

**構成確認:** 専用helperは更新前に旧containerとwrapperを退避し、次のScroll sessionが起動できたときだけ更新をcommitし、
起動失敗時は両方をrollbackする。
**推論:** 稼働中sessionは次回loginまで旧containerに依存し得る。通常の`distrobox assemble --replace`だけでは、更新失敗時に
login可能なcompositorとexport wrapperを同時に失う可能性がある。このtransactionはGUI resource共有ではなく、container化した
session component特有の更新境界を補うものである。

## 限界と未解決事項

### 原理的な限界

- containerはhost kernelを共有する。kernel、DRM、input、network、filesystem、driverの挙動を別distributionのものへ
  差し替えることはできない。
- Wayland、D-Bus、PipeWire、SSH agentなどのsocketを共有できても、protocol、library、driver、認可policyのversion差まで
  Distroboxが吸収するわけではない。
- host serviceからcontainer processを起動し、containerからhost commandを起動するため、process tree、PATH、filesystem
  path、environmentの出所は一つにならない。障害調査では「どちらのrootfsで動いているか」を常に確認する必要がある。
- container imageをrollbackしても、共有HOMEにapplicationが書いた設定やcacheはrollbackされない。

### 現在の構成に残る制約

- runtime pathとX11 mountにUID `1000`を直接含む。別UIDへのportableな構成にはなっていない。
- `scroll.ini`がexportするのはbinaryだけで、container側のman page、Wayland session entry、icon、shell completionはhostへ
  同期されない。現状必要な利用経路と、exportまたはbind mountのどちらが適切かは**未確認**である。
- system D-Bus socket全体をmountしている。Scroll/logindに必要な最小interfaceへ狭める仕組みは設けておらず、そもそも
  Distroboxをsecurity boundaryとしない本方針ではsecurity対策として扱わない。
- host root、HOME、`/dev`、`/sys`、runtime directoryが広く共有される。これは**Live確認**済みの意図した統合であり、
  「container内だからhostを変更できない」という前提は成立しない。
- **推論:** session環境は起動順序と`uwsm finalize`に依存する。古いsocket pathを保持したprocessや、finalize前に起動したserviceを
  自動的に修復できるとは限らない。
- **推論:** host/containerのScroll wrapper、image、設定にversion skewが起きる余地がある。transactional updateは起動失敗からは
  rollbackするが、起動後の全機能や長時間動作までcommit前に保証するものではない。

## 新しいGUI containerの確認項目

1. container化の理由が別distributionのrootfs/package availabilityであり、隔離ではないことを確認する。
2. application binaryと依存library以外は、hostとcontainerのどちらが所有するかを資源ごとに決める。
3. 必要なWayland/X11、audio、D-Bus、device、GPUのsocket・mount・環境変数を最小の代表経路でlive確認する。
4. hostからcontainer、containerからhostのcommandを区別し、export wrapperかhost-execを明示する。
5. PAM、polkit、keyring、portal、systemd user serviceをcontainerへ複製する必要が本当にあるか確認する。
6. desktop entry、icon、MIME、man page、completion、session entryのうち、hostへ公開する成果物を決める。
7. image replacement中も利用中processとexport wrapperが整合するか、失敗時に復旧できるか確認する。
8. 検証結果を「確認済み」「仕様上の限界」「現在未実装」「未確認」に分け、推測を制約として固定しない。

## 参照

- [Distrobox: What it does / Security implications](https://distrobox.it/#what-it-does)
- [distrobox-export](https://distrobox.it/usage/distrobox-export/)
- [distrobox-host-exec](https://distrobox.it/usage/distrobox-host-exec/)
- [distrobox-assemble](https://distrobox.it/usage/distrobox-assemble/)
- [UWSM](https://github.com/Vladimir-csp/uwsm)
- [Scroll](https://github.com/dawsers/scroll)
