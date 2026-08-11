# Ghostty GTKタイトル文字上端欠けの調査

調査日: 2026-08-11

## 概要

Scroll Waylandセッション上のGhosttyで、タイトルおよびタブの文字上端が約1 px欠ける。
調査の結果、再現に必要な条件は次の組み合わせまで絞り込めた。

- IBM Plex Sans JP Regular
- device pixelへ変換したフォントサイズが非整数
- GTK 4.22.4の`GskGLRenderer`

同じフォントでも整数pixel sizeまたはCairo rendererでは再現しない。GPU、Mesa driver、
Scrollのoutput/content scaling、ユーザーGTK CSS、IBM Plex Sans JPのversionおよびhintingは
必要条件ではなかった。

## 対象環境

| 項目 | 値 |
| --- | --- |
| Ghostty | 1.3.1-2.fc44 |
| GTK | build 4.22.3、runtime 4.22.4 |
| libadwaita | build 1.9.0、runtime 1.9.2 |
| Pango | 1.57.1 |
| compositor | Scroll、Wayland |
| GPU | AMD Radeon RX 9070 XT |
| Mesa | 26.1.6 |
| kernel | 7.1.5-ogc5.1.fc44.x86_64 |
| 問題が見えるoutput | DP-1、5120x1440@119.999 Hz、scale 1.0 |

GhosttyはGTK 4.16以降で`GDK_DISABLE=gles-api,vulkan`を設定する。そのため、この環境では
GTKがWayland surface用に`GskGLRenderer`を選択する。Ghosttyの端末本体は別のOpenGL
rendererを使用しており、本件の対象はGTK UIである。

ライブGTK設定には次が存在した。

```ini
gtk-font-name=IBM Plex Sans JP,  10
gtk-xft-dpi=122880
```

120 DPIにおける10 ptは約16.667 device pixelであり、確認した失敗条件に一致する。この設定は
chezmoi管理外だった。生成元は未確認であり、DankMaterialShellが生成した可能性はあるが、本調査では
断定していない。

## 観測結果

### Renderer、font、size

| 条件 | 結果 |
| --- | --- |
| IBM Plex Sans JP Regular、10 pt = 13.333 px、OpenGL | 上端が欠ける |
| IBM Plex Sans JP Regular、9.75 pt = 13 px、OpenGL | 正常 |
| IBM Plex Sans JP Regular、9 pt = 12 px、OpenGL | 正常 |
| IBM Plex Sans JP Regular、10 pt、Cairo | 正常 |
| Adwaita Sans Regular、10 pt、OpenGL | 正常 |
| IBM Plex Sans JP synthetic Bold、10 pt、OpenGL | 正常 |

最小GTK/libadwaitaアプリで解決済みPango font descriptionを取得し、Regularが
`IBM Plex Sans JP 13.333px`、synthetic Boldが`IBM Plex Sans JP Bold 13.333px`であることを
確認した。インストール済みIBM Plex Sans JPはRegular 1書体だけであり、BoldはFontconfig/Pangoが
合成している。

### 除外した候補

| 候補 | 反証 |
| --- | --- |
| ユーザーGTK CSSまたは`settings.ini`全体 | 別の`XDG_CONFIG_HOME`で完全に除外しても再現 |
| `gtk-xft-dpi=122880`単独 | `GDK_DPI_SCALE=0.8`でも再現 |
| IBM Plex Sans JP v1.0固有 | upstream v1.3でも再現 |
| TrueType hinting | v1.3のhinted/unhinted TTF双方で再現 |
| RX 9070 XTまたはradeonsi固有 | `LIBGL_ALWAYS_SOFTWARE=true`のllvmpipeでも再現 |
| GSK GPU最適化 | `GSK_GPU_DISABLE=all`でも再現 |
| partial redrawだけ | `GSK_DEBUG=full-redraw`でも再現 |
| Scrollのfractional output scale | 対象DP-1はscale 1.0 |
| Scrollの個別content scale | Ghostty nodeに`scale_content`なし |
| Ghostty固有の文字layout | 最小`Gtk.Label`でもIBM Plex Sans JP Regular 10 ptで再現 |

XWaylandでは同じ見た目を再現しなかったが、window decorationの経路がWayland版と異なるため、
単独では反証として扱わない。

## 原因

確定できた原因範囲は、IBM Plex Sans JP Regularを非整数pixel sizeで使ったときの、
GTK 4.22.4 GPU rendererのglyph描画経路である。rasterization、atlasへのupload、bounds変換および
samplingのどの段階で1 px失われるかは未確定である。

有力な仮説は、Pangoが返すglyph boundsと、GPU rendererが作成またはsampleするglyph atlas矩形の
pixel境界が一致しないことである。

GTK 4.22.4の`gsk_gpu_cached_glyph_lookup()`は、Pangoから取得したink rectangleを
`floor()`と`ceil()`でpixel-alignedなatlas矩形へ変換し、1 pxのpaddingを付けてCairoでglyphを
atlasへuploadする。観測結果からは、この処理または後続samplingでIBM Plex Sans JP Regularの
上端coverageが描画対象boundsの外へ1 px落ちると推定できる。

該当箇所:

- [GTK 4.22.4 `gskgpucachedglyph.c`](https://gitlab.gnome.org/GNOME/gtk/-/blob/4.22.4/gsk/gpu/gskgpucachedglyph.c#L186-238)

整数pixel sizeでは正常になり、GPU glyph atlas経路を使用しないCairo rendererでも正常になる。
ただし、本調査ではGTK内部のatlas textureまたはrender nodeを直接captureしていない。atlasの内容、
upload rectangleおよびsampling boundsの比較が、この仮説を確認するために必要である。

GTKには、統合GL/NGL rendererで文字上端が1 px欠け、旧GL rendererでは正常だった類似事例がある。
今回の再現はGPU vendorに依存せず、現行GTK 4.22.4とIBM Plex Sans JPで発生する。

- [GTK #6433: Text clipping issue with NGL on Nvidia](https://gitlab.gnome.org/GNOME/gtk/-/work_items/6433)
- [GTK #8339: Partial redraws are off by 1 pixel](https://gitlab.gnome.org/GNOME/gtk/-/work_items/8339)

#8339は症状が似ているが、そこで示された`GSK_DEBUG=full-redraw`では本件が直らないため、同一原因とは
扱わない。

## 最小再現

次のPythonスクリプトをシステムPythonのPyGObjectで実行する。GTK、libadwaitaおよび
IBM Plex Sans JPが利用可能であることを前提とする。

```python
#!/usr/bin/python3
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk


class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id="dev.atty.GtkGlyphClipRepro")

    def do_activate(self):
        window = Adw.ApplicationWindow(application=self)
        window.set_default_size(900, 220)

        css = Gtk.CssProvider()
        css.load_from_string(
            '* { font-family: "IBM Plex Sans JP"; font-size: 13.333333px; }'
        )
        Gtk.StyleContext.add_provider_for_display(
            window.get_display(),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        label = Gtk.Label(label="chezmoi | Ready | iii ttt fff")
        window.set_content(label)
        window.present()


App().run(None)
```

再現:

```sh
mkdir -p /tmp/gtk-glyph-clip-repro-config
XDG_CONFIG_HOME=/tmp/gtk-glyph-clip-repro-config \
  GDK_BACKEND=wayland \
  GSK_RENDERER=opengl \
  GSK_DEBUG=renderer \
  /usr/bin/python3 repro.py
```

Cairoによる比較:

```sh
XDG_CONFIG_HOME=/tmp/gtk-glyph-clip-repro-config \
  GDK_BACKEND=wayland \
  GSK_RENDERER=cairo \
  GSK_DEBUG=renderer \
  /usr/bin/python3 repro.py
```

標準エラーに`Using renderer 'GskGLRenderer'`または`Using renderer 'GskCairoRenderer'`が出ることを
確認する。CSSの`13.333333px`を`13px`または`12px`へ変更すると、OpenGLでも正常になる。

### 追試用コマンド

実行中のrenderer選択:

```sh
GSK_DEBUG=renderer ghostty --gtk-single-instance=false
```

llvmpipeによるGPU driver除外:

```sh
LIBGL_ALWAYS_SOFTWARE=true GSK_RENDERER=opengl \
  GSK_DEBUG=renderer ghostty --gtk-single-instance=false
```

GSK GPU最適化の一括無効化:

```sh
GSK_GPU_DISABLE=all GSK_RENDERER=opengl ghostty --gtk-single-instance=false
```

DPI scaleとfull redrawの反証:

```sh
GDK_DPI_SCALE=0.8 ghostty --gtk-single-instance=false
GSK_DEBUG=full-redraw ghostty --gtk-single-instance=false
```

最小再現のCSSでfont familyまたはweightだけを変更する比較:

```css
/* Adwaita Sans Regular: 正常 */
* { font-family: "Adwaita Sans"; font-size: 13.333333px; font-weight: 400; }

/* IBM Plex Sans JP synthetic Bold: 正常 */
* { font-family: "IBM Plex Sans JP"; font-size: 13.333333px; font-weight: 700; }
```

XWayland比較:

```sh
GDK_BACKEND=x11 GSK_RENDERER=opengl ghostty --gtk-single-instance=false
```

Fontconfigが選択したfaceとversion:

```sh
fc-match 'IBM Plex Sans JP:style=Regular' \
  -f '%{family}\t%{style}\t%{file}\t%{fontversion}\n'
```

Scrollのoutput scale:

```sh
distrobox enter scroll -- scrollmsg -t get_outputs --raw
```

ScrollのGhostty nodeと個別content scale:

```sh
distrobox enter scroll -- scrollmsg -t get_tree --raw \
  | jq '.. | objects | select((.app_id? // "") == "com.mitchellh.ghostty")'
```

upstream IBM Plex Sans JP v1.3のhinted/unhinted比較:

```sh
curl -fL -o /tmp/ibm-plex-sans-jp-2.0.0.zip \
  'https://github.com/IBM/plex/releases/download/%40ibm/plex-sans-jp%402.0.0/ibm-plex-sans-jp.zip'

unzip -jo /tmp/ibm-plex-sans-jp-2.0.0.zip \
  'ibm-plex-sans-jp/fonts/complete/ttf/hinted/IBMPlexSansJP-Regular.ttf' \
  -d /tmp/ibm-plex-sans-jp-v1.3
unzip -jo /tmp/ibm-plex-sans-jp-2.0.0.zip \
  'ibm-plex-sans-jp/fonts/complete/ttf/unhinted/IBMPlexSansJP-Regular.ttf' \
  -d /tmp/ibm-plex-sans-jp-v1.3-unhinted
```

各directoryについて、次の`fonts.conf`の`<dir>`を対象directoryへ合わせる。

```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>/tmp/ibm-plex-sans-jp-v1.3</dir>
</fontconfig>
```

一時fontだけが選択されることを確認してから最小再現を実行する。

```sh
FONTCONFIG_FILE=/tmp/ibm-plex-sans-jp-v1.3-fonts.conf \
  fc-match 'IBM Plex Sans JP' \
  -f '%{family}\t%{style}\t%{file}\t%{fontversion}\n'

FONTCONFIG_FILE=/tmp/ibm-plex-sans-jp-v1.3-fonts.conf \
  XDG_CONFIG_HOME=/tmp/gtk-glyph-clip-repro-config \
  GDK_BACKEND=wayland \
  GSK_RENDERER=opengl \
  /usr/bin/python3 repro.py
```

v1.3 hinted/unhintedはともに再現した。v1.3 hintedはfontversion 65733、既存v1.0は65602だった。

## 回避策

確認済みの回避策は次のいずれかである。

- Ghosttyだけ`GSK_RENDERER=cairo`で起動する。
- GTK UI fontをAdwaita Sansなど、同じ条件で再現しないfontへ変更する。
- GTK UI font sizeとDPIの積が整数device pixelになるよう調整する。

`GSK_RENDERER=cairo`はGTK UIをsoftware renderingへ変更する。Ghosttyの端末本体のOpenGL
rendererは維持されるが、GTKのCairo rendererは比較・fallback用であり、恒久策としてはGTK側の修正を
優先する。

## 未確認事項

- GTKのglyph atlasまたはrender node captureによる、欠落pixelとatlas boundsの直接比較
- GTK main branchでの再現有無
- GTK upstreamへの新規issue報告と既存issueとの重複判定
- `~/.config/gtk-4.0/settings.ini`の生成元
