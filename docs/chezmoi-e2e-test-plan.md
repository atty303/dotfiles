# chezmoi フル E2E テストスイート計画

## 目的

ローカルの作業ツリーを毎回クリーンな対象環境へ転送し、実際の `chezmoi init --apply` を最後まで実行する E2E テストスイートを追加する。

現在実装済みの対象環境は次の4系統とする。

- Bazzite 44 desktopコンテナ
- Fedora 44互換性コンテナ
- Ubuntu 24.04 devcontainer（desktop/headless）
- Tart上のmacOS VM

macOS E2EはApple Silicon Mac自身から実行する。LinuxからMacへ接続するremote backendは持たない。WindowsとAWS EC2 MacのE2Eは未実装の将来構想として、現在の検証保証から分離する。

テンプレート描画だけ、scriptsを除外したapply、dry-runだけのスモークテストは作らない。lifecycle scripts、externals、パッケージ導入を含むフルapplyを検証対象とする。ただし個人用secretはゲストへ渡さず、テスト専用の一時的な暗号化fixtureへ置き換える。

## 合格条件

各対象環境で次の処理がすべて成功した場合に合格とする。

1. クリーンなユーザーHOMEからbootstrapする。
2. 現在の作業ツリーをsource stateとして初回のフルapplyを完了する。
3. 常時実行scriptを除く `chezmoi verify` で管理対象とtarget stateが一致する。
4. OS固有のファイル、symlink、実行属性、主要パッケージを検証する。
5. 一時age鍵で暗号化したsentinelが正しく復号・配置される。
6. `chezmoi apply --dry-run --verbose` が成功し、Linuxでは意図した `run_always` script以外の追加変更が予定されない。
7. 実際に2回目の `chezmoi apply` を実行し、終了コード0になる。
8. 2回目のapply後にも常時実行scriptを除く `chezmoi verify` が成功する。

OS再起動後のサービス、ログインセッション、GUI承認状態までは初期スコープに含めない。

## ユーザー向け実行インターフェース

トップレベルのmise設定から次のタスクを公開する。

```sh
mise run test:e2e
mise run test:e2e:harness
mise run test:e2e:linux
mise run test:e2e:linux:bazzite
mise run test:e2e:mac:prepare
mise run test:e2e:mac:local
```

`test:e2e` はhost OSだけを基準に対象を選択する。LinuxではBazziteを除く標準3対象、macOSではlocal Tart E2Eを実行し、それ以外のOSでは未対応として終了する。`test:e2e:harness` はarchive、age fixture、対象選択およびcleanupをcontainerやVMなしで検証する。

テストログ、VM overlay、展開済みsource、生成した鍵などの実行時データは、リポジトリ管理外の `.cache/chezmoi-e2e/` 以下へ保存する。

## 共通E2Eハーネス

`tests/e2e/` に、環境固有driverから再利用する共通ハーネスを配置する。

### 作業ツリーのステージング

- コミット済みrevisionではなく、未コミット変更を含む現在の作業ツリーを対象にする。
- `.git`、E2Eキャッシュ、VM image、実行ログ、個人用秘密鍵を除外して一時tar archiveを作る。
- 個人用の暗号化ファイルと `key.txt.age` はゲストへ渡さない。
- archiveのSHA-256をログへ残し、各OSが同じ入力を使用したことを確認できるようにする。
- archiveはゲスト内の一時ディレクトリへ展開し、テスト終了後に破棄する。

### テスト用age fixture

- 各テスト実行時に新しいage identityとrecipientを生成する。
- 固定のsentinel平文を生成したrecipientで暗号化し、一時source stateへchezmoiのencrypted entryとして追加する。
- private identityは環境変数 `CHEZMOI_AGE_KEY` または `/usr/local/secrets/CHEZMOI_AGE_KEY` でゲストへ渡し、通常のidentity準備scriptで使い捨てHOMEへ保存する。
- stdout、stderr、verbose logへidentityを出力しない。
- chezmoi source stateにはE2E専用flagやrecipient分岐を追加しない。復号にはrecipient設定を使わず、fixtureに対応するidentityだけを供給する。
- Linux、macOS、Windowsのdecrypt前スクリプトを揃え、供給されたidentityをprivate permissionで永続化する。
- リポジトリへテスト用private key、plaintext credential、復号済み個人データをコミットしない。

### 共通検証

初回apply後に最低限、次を確認する。

LinuxとmacOSでは、lifecycle script内の `mise install` だけを最大3回、失敗後2秒・4秒の間隔で再実行する。

- 常時実行scriptを除く `chezmoi verify` が成功する。
- 暗号化sentinelが期待した内容とpermissionで配置される。
- `.local/bin` の主要external commandが存在し、実行可能である。
- OSごとに定義されたNushell、Code、mise互換layoutなどのsymlinkが存在し、正しい共有ファイルまたはdirectoryを指す。
- `mise ls --missing` が未導入toolを報告しない。
- 2回目のapplyで `run_once` / `run_onchange` の不要な再実行やtarget変更が発生しない。

ハーネスはsignalと異常終了に対するcleanup処理を持つ。失敗時のresource削除または保持はbackendごとの方針に従う。

## Linux E2E

### 対象

- Bazzite 44 desktop（local専用）
- Fedora 44（local/CI）
- Ubuntu 24.04 devcontainer desktop（local/CI）
- Ubuntu 24.04 devcontainer headless（local/CI）

`test:e2e:linux` はBazziteを除く標準3対象を実行する。Bazziteはlocal専用の特殊対象として、必要な場合だけ`test:e2e:linux:bazzite`から明示的に実行する。
Ubuntuのdesktop targetにはWayland session定義を置き、headless targetには置かない。Linuxの
`desktop` role判定は`/usr/share/wayland-sessions/*.desktop`または
`/usr/share/xsessions/*.desktop`の存在だけで変わり、実行中session、container、systemd、
Flatpak、XDG commandの状態には依存しない。
FedoraはFedora系の軽量な互換性対象とし、Bazziteは実際のdesktop hostに近い統合対象とする。

### 実行方式

- rootless Podmanを使用する。
- FedoraとUbuntuのContainerfileには、証明書、curl、git、archive展開などbootstrapに不可欠なOSパッケージだけを入れる。Ubuntu desktop stageだけはXDG handler登録用commandも入れる。
- chezmoi、mise、mise管理tool、fonts、externalsはimageへ事前導入せず、テスト対象のbootstrap/applyに導入させる。
- rootではなく専用の一般ユーザーと独立HOMEを作り、通常のdotfiles適用に近い条件にする。
- source archiveはコンテナへコピーし、target HOMEとchezmoi stateはコンテナ固有volumeに置く。
- CI対象の3環境は同じ共通検証を通し、command capabilityに応じてscriptの実行結果またはskip結果を検証する。

Bazziteは汎用desktop imageをdigest固定し、rootless Podmanのprivileged systemd containerでuser sessionを起動する。`desktop` roleでsystem Flatpak全件とDistrobox全件を実際に作成する。大容量download、cgroup v2およびnested Podmanを必要とするためGitHub Actionsでは実行しない。

stage時に実際の`.age` fileを除外し、実行ごとに生成したage identityとrecipientで暗号化sentinelを一時source stateへ追加する。chezmoi側へE2E専用dataやrecipient分岐は持たせず、通常の`secrets` roleとidentity供給経路で配置・復号する。

Podman containerはLinuxカーネルやsystem serviceの構成検証には使わない。今回のLinux scriptsが行うユーザーHOME、mise、fonts、terminfo、externalsのE2Eに限定する。

## 将来構想: Windows E2E（未実装）

この節は現在の実行インターフェースおよび検証保証に含まれない。着手時には前提、使用image、実行方式および費用を再検証する。

### 対象

- Windows 11 24H2以降
- x86_64
- roles: `development`、`desktop`、`gaming`、`secrets`を有効化（`work`はpolicy検証時だけ選択）

GitHub等のWindows Server runnerは使用しない。Sudo for WindowsとクライアントOS固有設定を検証するため、実際のWindows 11 VMを使用する。

### ホスト準備

このBazziteホストでは、公式の `ujust setup-virtualization` を使ってKVM/libvirtを有効化する。

必要なhost capabilityは次のとおり。

- `/dev/kvm`
- libvirt
- QEMU/KVM
- UEFI/OVMF
- swtpmによるTPM 2.0
- virtio storage/network

### ベースイメージ

Packer定義とunattended setupをリポジトリへ追加し、ユーザーが指定するWindows ISOとvirtio ISOからgolden qcow2を作成する。

golden imageにはテストtransportとOS prerequisiteだけを含める。

- Windows 11 24H2+
- OpenSSH Server
- winget
- PowerShell
- UEFI Secure Boot互換構成
- TPM 2.0
- virtio driver
- テスト用ローカル管理者

chezmoi、mise、DSC、winget role packages、dotfilesはgolden imageへ含めない。Windows ISO、product key、license情報、administrator passwordはリポジトリへ保存しない。

### テスト実行

- golden imageからテストごとにcopy-on-write qcow2 overlayを作る。
- disk上限は全roles、Visual Studio Build Tools、Docker Desktopを収容できるよう200GBとする。
- READMEに記載されたSudo for Windows、ExecutionPolicy、symlink prerequisiteをテストsetupとして適用する。
- `install.ps1 --prompt-roles`からchezmoiをbootstrapし、ローカルsource archiveを指定して対象rolesでapplyする。
- `winget list` でdata fileに列挙された全packageを検証する。
- `dsc config test` でWindows DSC構成を検証する。
- 共通のverifyと2回目applyを実行する。
- VMを停止し、overlayを削除する。golden imageは再利用する。

VMの初回作成と日常E2Eは別タスクにし、通常のテストでWindowsインストールからやり直さない。

## macOS E2E

### 共通方式

- macOS 26のTart base imageをOCI digestで固定する。
- テストごとに一意な名前でbase imageをcloneする。
- guest resourceをCPU 6、RAM 10GBに固定する。
- source archiveとage fixtureをread-only directoryとしてguestへmountし、Tart Guest Agentの `tart exec` でguest処理を起動する。
- フルapply、`chezmoi verify`、`mise bootstrap packages status --missing`、`mise ls --missing`、2回目applyを実行する。
- 成否にかかわらずguestを停止し、テスト用Tart cloneを削除する。

Tart hostにはテスト対象のdotfilesを直接applyしない。

### Local Mac host

前提条件は次のとおり。

- Apple Silicon Mac
- macOS 14以降
- Tartを実行できる空きdisk、memory、Virtualization.framework

Mac上で `mise run test:e2e:mac:local` を使用する。`mise run test` からはhost OS判定により同じlocal E2Eが選択される。

Macホストにはmiseだけを事前に導入する。TartはmacOS arm64限定のmise toolとしてversionを固定し、Homebrewには依存しない。global `miserc.toml` の `auto_env = true` で `config.macos.toml` を自動読込し、macOS packageはmise bootstrap経由で管理する。

macOS 15以降では、Virtualization.frameworkがVM起動時にunlock済みのlogin keychainを要求する。専用ユーザーで一度GUIログインし、そのsessionとlogin keychainをunlockした状態に保つ。keychain passwordはE2E runnerへ渡さない。

初回はMac上のcheckoutで次を実行する。

```sh
mise trust
mise install
mise run test:e2e:mac:prepare
```

prepare taskはhostのOS、architecture、CPU、memory、disk、login keychainを検査し、digest固定のmacOS 26 imageを取得する。さらに一時VMをCPU 6、RAM 10GBで起動し、Tart Guest Agent経由のcommand実行まで確認してからVMを削除する。実行ごとに専用の一時TART_HOMEを使用し、Tartのcacheと取得済みbase imageだけを永続cacheから再利用する。prepare taskはRemote Login、GUI session、keychainやmacOS defaultsを変更しない。

## 将来構想: AWS Mac backend（未実装）

この節は現在の実行インターフェースおよび検証保証に含まれない。以下は設計候補であり、着手時にregion、instance、接続方式、IAMおよび費用を再検証する。

AWS Singaporeリージョン `ap-southeast-1` の `mac2.metal` Dedicated Hostを使用する。東京 `ap-northeast-1` は現時点でIntel Mac1のみであるため、Apple Silicon/Tart構成の標準backendにはしない。

AWS構成は次のとおり。

- リージョン: `ap-southeast-1`
- instance type: `mac2.metal`
- architecture: Apple M1 / arm64
- AWS提供macOS AMI
- SSM Agentとinstance profile
- internetへのSSH ingressなし
- ローカルからの接続はSession ManagerのSSH ProxyCommandを使用

host起動後に固定versionのTartを導入し、local Mac E2Eと同じguest処理を再利用する案とする。Marketplace AMIへの依存は必須にせず、通常のAWS macOS AMIから再現できるようにする。

Dedicated Hostには最低24時間のallocationがあるため、作成時にクラウド側のcleanupを必ず予約する。

1. host/instance作成直後にEventBridge Schedulerのone-shot scheduleを作る。
2. allocation開始から24時間後にEC2 Mac instanceをterminateする。
3. AWSのscrubbing時間を考慮した時刻にDedicated Hostをreleaseする。
4. cleanup用IAM roleとschedule名へE2E run IDを付ける。
5. ローカルprocessが終了・停止してもcleanupが実行されるようにする。
6. cleanup予約に失敗した場合はテストを開始せず、作成済みリソースを可能な範囲で即時停止してエラーにする。

AWS backendは次の場合に自動fallbackしない。

- `mac2.metal` quota不足
- Dedicated Host capacity不足
- Singaporeリージョン障害
- IAM/SSM設定不足

別リージョンや別instance typeへ切り替えると費用と検証architectureが変わるため、明示的な設定変更を要求する。

## 設定とsecretの管理

リポジトリへ保存してよいのは非secretの既定値とschemaだけとする。

環境変数またはリポジトリ外のローカル設定として扱う値には次を含める。

- Windows ISO pathとSHA-256
- virtio ISO pathとSHA-256
- Windows administrator password
- Windows license/product key
- AWS profile、account、subnet、IAM設定
- AWS Session Manager接続情報

AWS credential、SSH private key、Windows credential、age identityをテストログへ出力しない。ゲストへ渡した一時credentialはcleanup時に消去する。

## 障害時の成果物

失敗時には秘密情報を含まない次の情報を `.cache/chezmoi-e2e/logs/<run-id>/` へ残す。

- 対象OS、version、architecture
- source archive SHA-256
- 初回applyのstdout/stderr
- `chezmoi verify` の結果
- 2回目applyのstdout/stderr
- package/DSC/brew検証結果
- VM/container/Tartのconsole log
- cleanup結果
- AWS backendではregion、instance ID、Dedicated Host ID、cleanup schedule ID

age identity、復号済み個人secret、Windows password、AWS tokenはredactする。

Linux E2Eは成功時にcontainerとhome volumeを削除し、cleanup失敗もテスト失敗として扱う。テストまたはcleanupの失敗時は即時調査できるように残存resourceを保持し、log directory、container/volume名、起動、shell接続、install再実行および削除コマンドを標準エラーへ表示する。保持したresourceは調査後に表示されたコマンドで明示的に削除する。

LinuxとmacOSのE2Eはchezmoi外の各工程の開始時に短い名前を表示する。失敗時は最後のstep表示、chezmoiのverbose出力、終了コードおよびlog directoryから失敗箇所を特定する。

## 実装状況

共通archive、age fixture、OS別guest assertion、cleanup、標準Linux 3対象、local Bazziteおよびlocal Mac Tart driverは実装済みである。WindowsとAWS Macは上記の将来構想を実装する決定が行われた場合だけ、前提を再検証して個別に設計・実装する。

## 前提と制約

- Local MacはApple Siliconとし、Intel Mac backendは作らない。
- Fedora/Ubuntu containerではsystemdやhost kernel設定の妥当性を保証しない。
- GUIアプリの初回起動、macOS system extensionのユーザー承認、Windows再起動後のdesktop状態は初期スコープ外とする。

Windows ISO、license、AWS quota、capacity、IAMおよび課金条件は現在の前提には含めず、各将来構想へ着手するときに確認する。

## 参考資料

- [Bazzite `ujust setup-virtualization`](https://docs.bazzite.gg/Installing_and_Managing_Software/ujust/)
- [Amazon EC2 instance types by Region](https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-regions.html)
- [Amazon EC2 Mac instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-mac-instances.html)
- [Tart Virtualization](https://tart.run/)
- [chezmoi common flags and entry types](https://www.chezmoi.io/reference/command-line-flags/common/)
