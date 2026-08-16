# 技術選定

Status: Living
Last updated: 2026-08-16

## 目的

この文書は、このdotfilesで使う技術とその選定理由を記録するliving architecture decision catalogである。
過去の採用経緯を推測するのではなく、現在の構成と運用を、現時点の判断として説明する。

通常のimmutableなADRとは異なり、この文書は常に最新の判断へ更新する。version、download URL、checksum、
対象platformなど機械が利用する情報は設定を原典とし、ここには複製しない。実際の導入対象は
[`home/dot_local/bin/`](../home/dot_local/bin/)や各toolの設定を参照する。

状態は次の意味で使う。

- **採用**: 現在の標準、または日常的に使うtool。
- **役割限定**: 特定platform、互換性、または限定された用途のために使うtool。
- **試用中**: 価値を評価中で、標準として確定していないtool。
- **比較中**: 同じ領域の複数候補から標準を決めていない状態。
- **休眠**: 設定や導入経路は残っているが、現在は利用していないtool。

## 選定原則

最優先するのは、再現性と明確な責務境界である。単一のtoolですべてを統一するのではなく、各層が所有する
状態を限定し、同じ入力から環境を復元できる構成を選ぶ。

- portableなCLIと操作語彙はLinux、macOS、Windowsで共有する。
- system設定、GUI application、package導入などOSとの統合は、各OSで自然なnative機構へ任せる。
- 役割が異なり、その違いを説明できるなら、近い機能を持つtoolの併存を許容する。
- 対話時の便利さだけでなく、clean environmentからの導入、versionの固定、失敗時の観測可能性まで選定に含める。
- 導入されていることと、標準として採用済みであることを区別する。
- 外部accountやdeviceへ強く結合する状態は、再現性を装って自動化せず、必要なら手動境界として残す。

## 環境の収束とtool供給

### chezmoi — 採用

chezmoiをhome directoryのsource of truthにする最大の理由は、一つのsourceからOSと複数roleの差を
templateのdataとして表現できることにある。managed fileだけでなく、secret、external resource、lifecycle scriptを
同じ適用modelへ置けるため、コピーした設定群ではなく、目的の状態へ収束する環境として管理できる。

単純なsymlink farmではplatform差とsecretの別管理が必要になり、汎用configuration managementでは個人HOMEに対して
system管理相当の複雑さを持ち込みやすい。Nix/Home Managerのように環境全体を別のpackage modelへ寄せる方法も採らない。
このrepoではnative integrationを残しつつ、HOMEの差分だけをchezmoiが所有する方が境界が明確だからである。

### mise — 採用

miseを選ぶ最大の理由は、project directoryごとにruntimeとversionを切り替え、同じ設定から実行環境を再現できることに
ある。その上で、portable binary、複数のpackage backend、repository taskも一つの入口から扱う。

globalなCLIはversioned tool stubとして `~/.local/bin` に公開する。shell activationの有無にかかわらずcommand pathを
安定させながら、platform別artifactとchecksumをsource管理できるためである。OS package managerだけに依存すると
platformごとにversionとavailabilityが分かれ、個別installerを並べると更新規則が重複する。asdfはruntime切替には
適するが、この環境が必要とするportable binary、task、package backendまでを同じ境界で扱えない。

miseは万能package managerではない。OS設定やnative applicationを所有せず、LinuxのFlatpak、WindowsのwingetとDSC、
macOSのHomebrew、必要なDistrobox imageへ処理を委譲する。

### secretとidentity — 採用

repositoryへ置くsecretは、chezmoiと直接統合でき、小さな鍵でfile単位に暗号化できるageを使う。GPGのweb of trustや
複雑なkeyringをdotfiles暗号化へ持ち込まず、復号identityの配布だけを明示的なbootstrap境界にする。

1Passwordはpassword、SSH agent、commit署名のnativeな保管場所として使う。ageと競合する選択ではなく、ageは
repositoryに保存するciphertext、1Passwordは人間のcredentialとOS sessionへ接続するsecretを担当する。外部accountへの
loginそのものはchezmoiの収束対象にしない。

## OSとdesktop

### Linux / Bazzite — 採用

Linuxは主desktop兼開発環境である。Bazziteのimmutable hostは基盤の更新とrollbackをdistributionへ任せ、個人用toolを
host RPMとしてlayeringしない。portable upstream artifact、Flatpak、既存container imageの順に選び、mutableなuserspaceが
必要なapplicationだけをDistroboxへ置く。

これは「すべてcontainerへ入れる」方針ではない。desktop sessionとの統合はUWSMとsystemd user service、host上で自然に
動くapplicationはFlatpak、共通CLIはmiseというように、変更主体ごとに境界を分ける。
GUI applicationをDistroboxへ置く場合の責務境界、host統合、およびScrollで追加している設定の意図は
[`DistroboxによるGUI applicationのコンテナ化`](distrobox-gui-containers.md)を参照する。

AppImageしか単純なuser-space配布がないapplicationは、Gear Leverを標準の管理境界にする。Gear Leverが
`~/AppImages`への配置、application menuへの統合、icon、個別version、および更新操作を所有し、chezmoiは
Gear Lever自体、登録すべきentry、およびHTTPS更新元を宣言する。個々のAppImageのversionやchecksumは
source stateへ複製せず、更新と旧版の併存はGear Lever上で明示的に操作する。entryの削除は宣言を消すだけでは行わず、複数machineへ
収束するまで`state = "absent"`を残してGear LeverのTrash操作へ委譲する。AppImageはsandboxではないため、
配布元を信頼できるapplicationに限定し、Flatpakが適する場合の第一候補にはしない。

Scrollはscrollable tilingを理由に採用している。固定されたtileやworkspaceへwindowを押し込むより、横方向へ連続する
window列を移動してfocusするmodelが作業方法に合う。Sway系の設定とIPCを利用できることも利点だが、選定の主目的ではない。
Hyprlandとniriは現在休眠している。

desktop shellはDankMaterialShellとNoctaliaを排他的に比較中である。両方を同時に常用する前提にはせず、hostとの統合、
必要機能、障害時の切り分け、container imageの保守コストから評価する。未確定の標準を文書上で作らない。

polkit、PAMおよびHowdyによる認証はimmutable hostの責務とする。Noctalia containerへhostのPAM stack、認証情報または
device設定をmountせず、Scroll sessionからはUWSMのsession targetを介してhostに既存のKDE polkit agentを起動する。
KDE sessionはPlasma本来の起動経路を維持し、どちらのdesktopでも同じhost PAM stackを利用する。

### Windows — 役割限定

Windowsはgaming、hardware utility、Windows専用softwareのために維持する。開発体験をWindows独自に作り直すのではなく、
共通CLIはmiseとNushellで共有し、applicationはwinget、system設定はDSCへ任せる。Linux相当の構成へ無理に寄せることも、
Windows固有の状態をportable toolへ隠すこともしない。

### macOS — 役割限定

macOSは仕事環境として維持する。CLIとrepository taskは他OSと共有する一方、application、keychain、launchd、GUI sessionなどは
macOSのnative機構を利用する。OS間で同じ見た目を作ることより、仕事で必要なnative integrationと共通の操作語彙を両立する。

## Shell、terminal、editor、version control

### Nushell (`nu`) — 採用

Nushellを主対話shellにする最大の理由は、外部commandの出力を文字列として連結するだけでなく、list、record、tableとして
変換できる構造化data pipelineにある。条件分岐や変換の意図をdata shapeで表せるため、複雑な `awk`、`sed`、quotingの連鎖を
日常操作から減らせる。command signature、module、網羅的な `match` も、表現力を重視する方針に合う。

Linux、macOS、Windowsで同じ設定とfunctionを共有できることも重要だが、bootstrap shellにはしない。Nushellを導入する前の
lifecycle scriptはUnixではBash、WindowsではPowerShellを使い、OSが確実に提供できる入口を保つ。POSIX shellとの互換性が
必要な外部scriptは無理にNushellへ移植せず、`^` によるexternal commandや生成されたshell integrationを境界として受け入れる。

Bash/Zshはbootstrapと互換性に優れるが、対話環境の主役にすると文字列pipelineとplatform別設定へ戻る。PowerShellは
structured objectを扱えるが、Unix CLIを中心とする日常環境をWindowsのobject modelへ寄せることになる。Fishの対話性だけを
採るより、data処理とcross-platform設定を一つの言語で扱えるNushellを選ぶ。

### terminal — 採用・役割限定・休眠

Ghosttyを主terminalにする。native UIと軽量なterminal coreを持ち、shell、multiplexer、promptの責務を内蔵機能で奪わない点を
評価する。Windowsではnative packageとして導入できるAlacrittyを使う。両者の設定から直接Nushellを起動し、terminalごとに
異なるshell体験を作らない。WezTermは現在休眠している。

### editorとIDE — 採用・役割限定

JetBrains製品を主IDEにする。選定理由は、editor単体の軽さよりも、build、test、debug、VCS、language toolingを一つの
一貫した開発体験として扱えることである。Helix (`hx`) はterminalで完結する編集の標準とし、modal editingと小さな設定で素早く
利用できる役割を持つ。VS CodeはRemoteやextensionなど必要な機能を補う補助IDEであり、設定量の多さを主IDEの根拠にはしない。

三者を一つへ統一すると、terminal編集、深いIDE統合、広いextension ecosystemのいずれかへ不要な妥協が生じる。役割を分けて
併存させる。

### Jujutsu (`jj`) とGit — 採用・役割限定

対応repositoryの日常操作にはJujutsuを使い、working-copy commitとchange中心のmodelで履歴編集を行う。Gitはrepository形式、
remote hosting、hook、未対応repositoryとの互換境界として残す。Git ecosystemを捨てるための選択ではなく、その上の操作modelを
Jujutsuへ置き換える選択である。Git-only repositoryではGitを使い、変換層を追加しない。

## CLI toolbox

portableなupstream CLIはmise tool stubから供給する。役割が近いtoolも、合成される場所や操作単位が異なる場合は併存させる。

### 検索、選択、移動

| Tool | 状態 | 選定理由と境界 |
| --- | --- | --- |
| ripgrep (`rg`) | 採用 | repositoryを尊重した高速な全文検索。標準`grep`はportable scriptへ残し、対話的なcode searchは`rg`を使う。 |
| fd | 採用 | 人間向けdefaultと簡潔なsyntaxを持つfile検索。POSIX `find`が必要なscriptを置き換えず、対話操作を担当する。 |
| fzf | 採用 | stdin/stdoutへ組み込める小さなfuzzy filter。shell widgetや他CLIの部品として使う。 |
| Television (`tv`) | 採用 | channel、preview、actionを持つ独立finder。既存pipelineへ埋め込むfzfとはUIの責務が異なる。 |
| zoxide | 採用 | 利用履歴からdirectory移動を短縮する。正確なpath指定やscriptの`cd`は置き換えない。 |
| Yazi | 採用 | previewとfile operationを持つterminal file manager。終了時のdirectoryをNushellへ返し、shellとの境界を明示する。 |
| eza | 試用中 | structuredで見やすいdirectory listingを評価中。標準`ls`を置き換える判断はまだ行わない。 |

fzfとTelevisionは代替候補ではない。filterを既存commandへ合成するときはfzf、sourceの選択からpreviewとactionまでを一つの
対話UIに任せるときはTelevisionを選ぶ。

### 表示、差分、prompt

| Tool | 状態 | 選定理由と境界 |
| --- | --- | --- |
| bat | 採用 | syntax highlightとpagingを持つtext viewer。機械処理では`cat`、人間が読む出力ではbatを使う。 |
| batman | 採用 | man pageをbatの表示体験へ接続し、pagerの操作と配色を揃える。man pageの取得や意味は変更しない。 |
| delta | 採用 | GitとJujutsuで共通の読みやすいdiff表示を提供する。diff生成やVCS操作は所有しない。 |
| vivid | 採用 | themeから`LS_COLORS`を生成し、file typeの配色を宣言的に揃える。listing tool固有のthemeへ重複定義しない。 |
| Starship | 採用 | shellをまたいで同じprompt情報を表示する。shell自体へVCSやruntime検出を作り込まない。 |
| jj-starship | 採用 | Jujutsu固有のchange情報をStarshipへ渡すadapter。汎用promptを独自実装しない。 |

### shell history、completion、session

Nushellのcompletionは、CLI自身が生成する `extern` とnu_scriptsの定義を優先する。全external commandを別processへ渡すと
通常のfile completionにも遅延が加わるため、global external completerは設定しない。利用頻度が高いmiseはcommandとtaskを
Nushellから直接取得し、それ以外の完全な補完だけusageへfallbackする。Carapaceは専用定義が有効なcommandへ `@complete` で
割り当て、Carapace bridgeとFish completion bridgeは有効にしない。

| Tool | 状態 | 選定理由と境界 |
| --- | --- | --- |
| Atuin | 採用 | SQLite history、host/workspace filter、同期可能な検索をshell間で共有する。shell固有の平坦なhistory fileだけに依存しない。 |
| gum | 採用 | shell functionに必要な一時的promptだけを小さなCLIで提供する。恒久的なTUI frameworkは導入しない。 |
| Zellij | 採用 | remote接続や長時間taskを含むterminal workspaceとsessionを管理する。terminal emulatorのtab機能へsession永続性を依存させない。 |
| nu_scripts | 採用 | CLI自身がNushell定義を生成しない場合の共有 `extern` を供給する。利用する定義だけを固定commitから取得する。 |
| usage | 役割限定 | miseのusage specから動的な候補を解決する。頻用経路には使わず、網羅性が必要な補完のfallbackに限定する。 |
| Carapace | 役割限定 | `deno` と `chezmoi` のcompletionへ個別に割り当てる。global completerや他shellへのbridgeとしては使わない。 |

### runtimeと開発tool

| Tool | 状態 | 選定理由と境界 |
| --- | --- | --- |
| Deno | 採用 | 新規automationとrepository scriptの標準。TypeScript実行、formatter、lint、type checkを単一runtimeで提供し、toolchainを小さく保つ。 |
| Node.js | 役割限定 | Node ecosystemを要求するprojectとtoolの互換runtime。新規automationのdefaultにはしない。 |
| Bun | 役割限定 | Bunを前提とするprojectのruntime/package workflowを再現するために置く。Denoの標準を置き換えない。 |
| rustup | 採用 | Rust toolchainとtargetをupstreamの標準経路で管理する。OS packageの古いtoolchainへ固定しない。 |
| cargo-binstall | 採用 | 利用可能なRust binaryはprebuilt artifactから導入し、日常bootstrapで不要なsource buildを避ける。 |
| Taplo | 採用 | TOMLのformat、lint、schema対応を一つのtoolへ集約する。汎用text formatterでTOML semanticsを近似しない。 |

Deno、Node.js、Bunを同格の標準にはしない。新規の個人automationはDenoを選び、projectが別runtimeを要求する場合だけmiseで
そのversionを再現する。

### platform、service、security

| Tool | 状態 | 選定理由と境界 |
| --- | --- | --- |
| GitHub CLI (`gh`) | 採用 | repository、issue、pull request、authenticationをGitHubの公式CLI境界で扱う。汎用HTTP scriptにAPI契約を複製しない。 |
| Ona CLI | 採用 | Ona/Gitpodのremote development environmentを操作する専用client。local environmentのbootstrapは担当しない。 |
| restic | 採用 | encryptedかつdeduplicatedなbackupを複数backendへ行える単一binary。dotfilesの収束とuser dataのbackupを混同しない。 |
| keyring | 採用 | OS keyringへCLIから接続する必要がある処理に使う。credentialをenvironment fileへ恒久保存する代替にはしない。 |
| UniClipboard (`uniclip`) | 試用中 | OSをまたぐclipboard共有候補。外部同期と常駐processの運用価値が確定するまでは標準にしない。 |

### coding agent

| Tool | 状態 | 選定理由と境界 |
| --- | --- | --- |
| Codex | 比較中 | repository作業をagentへ委譲する候補。特定vendorを唯一の実行基盤とはせず、実際のtask品質とintegrationで評価する。 |
| Claude Code | 比較中 | Codexと同じ領域の候補。両方を利用可能に保ち、現時点では標準agentを決めない。 |

### local adapterとwrapper

`~/.local/bin` にはupstream toolそのものに加え、platform差やsession境界だけを吸収する小さなwrapperも置く。
汎用frameworkへ抽象化せず、委譲先と追加する責務が一つずつ明確な場合に限定する。

| Tool | 状態 | 選定理由と境界 |
| --- | --- | --- |
| `login-nu` | 採用 | macOSではHomebrewのenvironmentを解決してからNushell login shellへ`exec`する。terminalへ環境解決を重複実装しない。 |
| `ssh-keygen-force-agent` | 採用 | process environmentにないSSH agent socketを管理済みfileから補い、実処理をOSの`ssh-keygen`へ委譲する。署名実装自体は所有しない。 |
| `wayland-session-exec` | 採用 | input-remapper presetをautoloadしてからWayland session commandへ`exec`する。session本体をwrapperの子processとして残さない。 |
| `atuin.bat` | 採用 | Windowsのcommand resolutionからAtuin stubを起動するadapter。Atuin本体のversionや導入方法は複製しない。 |
| `atty303.ahk` | 採用 | Windowsで左右Alt単独押下を日本語IMEの無変換・変換へ割り当てる。共通shell設定では扱えないnative input統合に限定する。 |

## 共通の見た目と操作

Zen Browserを通常browserとして採用する。Firefox基盤を維持してChromiumだけへ依存せず、vertical tabやworkspaceを中心とする
操作性を得られるためである。Chromeが必要なweb applicationや互換性確認までZenへ強制的に集約しない。

Catppuccin Mochaは、多数のterminal toolとGUI applicationへ同じpaletteを適用できる対応範囲を理由に採用する。個別applicationで
似た色を再実装せず、外部themeをchezmoi externalとして取得する。外観の完全一致より、contextを移動したときの視覚的一貫性を
優先する。

terminal fontにはUDEV Gothic Nerd Fontを使う。日本語と英数字が混在するcode・logの表示、programming向け字形、CLI promptや
file iconで使うNerd Font glyphを一つのfont familyで扱えるためである。GUI applicationのnative typographyまで同じfontへ
統一しない。

## この文書に含めない選択

Zoom、Slack、Discordなどの通信service、game、個別hardware utilityは、利用していても環境architectureの選定とはみなさない。
account、license、deviceの都合で選ぶapplicationまで収録すると、責務境界ではなくsoftware inventoryになるためである。

新しいtoolを追加するときは、導入方法だけでなく、既存toolと異なる役割、選定理由、使わない範囲、状態をこの文書へ反映する。
