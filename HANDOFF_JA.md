# PCBox 引き継ぎ

## 目的と作業方針

86Box ベースの PCBox を Socket 478 / PCI を中心とする構成へ段階的に整理する。不要な旧マシン、チップセット、オンボード機器、非 PCI 拡張機能を削減する一方、共有実装と動作中の機能を壊さないことを優先する。

- 一度に盲目的に削除せず、マシン登録、デバイス登録、関数・データ参照、CMake、テスト、既存設定との互換性を確認する。
- 今後、PCI スロットの挿し場所指定や既存コードの書き直しも予定されている。
- ISA という名称だけで削除しない。チップセット内の互換機能や RTC、割り込みなどは現行マシンにも必要な場合がある。AGP、USB、ACPI、IDE、SPD、APIC と PCI の配線にも注意する。
- 途中経過を細かく分割して報告せず、依頼された範囲をまとめて確認・作業する。
- ユーザーは GitHub Actions を実行しないよう指示したことがある。push 時の自動実行や手動実行には注意する。直近の push は `[skip ci]` を使用した。

## 現在の Git 状態

- リポジトリ：`Dareka5555/PCBox`
- 作業ブランチ：`arena/e6b14bbd-pcbox`
- この引き継ぎ作成直前の最新 push：`d7c754c Remove obsolete onboard devices [skip ci]`
- この引き継ぎファイル自体は作成時点では未コミット・未 push。

主な直近コミット：

- `d7c754c`：不要になったオンボード機器の整理。
- `44a671a`：新規設定の初期マシンを、削除済み `ibmpc` ではなく先頭の対応マシンに修正。
- `136d641`：未使用と判断した非 Intel チップセット実装 58 ファイルを削除。
- `81fcd75`：Linux の CI 構成を Qt 5 / x86_64 に整理。
- `01ef3e5`：Linux CMake ワークフローを手動実行のみに変更。
- `5db4a48`：Socket 478 向けの整理および ISA ROM 設定画面などの整理。

## 現在のマシンと維持すべき構成

- `src/machine/machine_table.c` に登録されているマシンは QDI PlatiniX 2（`platinix2`、Intel i845、Socket 478）。
- 初期化は `src/machine/m_at_socket478.c`。i845、ICH2、Winbond Super I/O、フラッシュ、SPD、CPU LAPIC、I/O APIC、および PCI スロット／割り込み配線を設定する。
- 主要なチップセット実装は `src/chipset/intel_845.c` と `src/chipset/intel_ich2.c`。それらが使う AGP ブリッジ、GART、SMRAM、SPD、ACPI、GPIO、NVR、SMBus、IDE、USB、TCO、I/O トラップ、APIC などは別ファイルにも分散している。
- 利用する BIOS ファイルは ROM ディレクトリ内の `machines/platinix2/P2_V23.BIN`。ROM は別途用意する。
- 既存の `machine_types` は設定 UI で種別 ID を添字に使う箇所があり、項目だけを削除すると不整合の恐れがある。チップセット enum の順序も `src/device/postcard.c` の比較で使われている。

## 完了した整理と残る注意点

- 非 Intel チップセットのうち、参照調査で削除候補となった 58 ファイルを CMake 登録・対応するヘッダー宣言とともに削除した。残っている非 Intel 実装には共有参照、テスト用、またはさらなる調査が必要なものがある。
- オンボード機器について、旧マシン専用実装 11 ファイル、未参照のオンボード向けデバイス定義 69 件と一部の専用ヘルパーを削除。PCI / AGP カードと共有する実装は維持した。
- PlatiniX 2 の ICH2 AC'97 作成処理は現在 `#if 0` で無効。未実装のオンボード音声を選べないよう `MACHINE_SOUND` フラグを除去した。古い設定で内蔵音声を指定していた場合は、未対応ハードウェアとして警告し、続行時は「なし」にする。今後 AC'97 を復活させる場合はデバイス実装と配線を含め再設計する。
- ISA ROM 設定タブと関連 UI 処理、VM 詳細画面の ISA RTC / RAM / ROM 表示を削除済み。ISA 関連の内部実装や他の UI がすべて削除済みという意味ではない。
- Voodoo / PowerVR には PCI 対応品があり、MO やテープは PCI SCSI コントローラー経由で利用できる場合がある。画像に表示される機器を PCI 以外と決めつけて一括削除しない。
- `doc/socket478-chipset-audit.md` にチップセット調査時の一覧がある。ただし調査後に変更が進んでいるため、特に `MACHINE_SOUND` が設定されているとの記述は古い。現コードを正として再確認すること。

## ビルドと動作確認

ユーザー環境は Debian 13（Linux）。ユーザー報告では、`d7c754c` の取得後のビルドとアプリケーション起動は問題なく完了した。ゲスト OS の起動、PCI / AGP・USB・ACPI・IDE・割り込みなどの個別機能検証まで完了したとは確認されていない。

以前の新規システム追加で子プロセスが終了コード 11 で落ちたが、初期マシンの修正 `44a671a` 後、ユーザーから追加画面に進めたとの報告があった。

Debian 側で以前案内した Qt 5 / SDL 2 Release ビルド（既存ビルドディレクトリ利用）：

```bash
cd ~/PCBox
git switch arena/e6b14bbd-pcbox
git pull --ff-only
cmake --build build-release -j 2
./build-release/src/PCBox
```

初回設定に使用した CMake オプション：

```bash
cmake -S . -B build-release -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DQT=ON -DUSE_QT6=OFF -DSDL2=ON \
  -DMUNT=OFF -DSOUNDCANVAS=OFF \
  -DDISCORD=OFF -DLIBRASHADER=OFF
```

作業環境側では、オンボード整理時に変更した C ソースの個別コンパイル、S3 display / accel テスト、Mach64 accel テストが通過。チップセット整理時には Intel 386EX DMA の独立テストも通過した。こちらの環境では FreeType 不足によりフル CMake 構成・実行はできなかった。

## GitHub Actions

- `.github/workflows/cmake_linux.yml`：手動のみ、Linux x86_64・Qt 5・Release / Debug の AppImage ビルド。
- Linux ARM は CMake と PR ビルドの対象から除外。従来の PR Linux ビルドは Qt 6 を使うため除外した。
- Linux CodeQL は Qt 5 の構成を残している。CMake ワークフローを手動にしたことは、すべての Linux 関連 Actions が手動になったという意味ではない。
- Windows 向けワークフローは別に存在する。変更時は実行条件を確認する。

## 次に進める場合

1. 現行コードと作業ツリーを再確認し、ユーザーの次の対象を優先する。
2. 残るオンボード専用処理や非 Intel チップセットについて、共有デバイス・条件付きビルド・テスト・設定互換性を含めて依存を確認する。過去の静的な未参照調査だけを根拠に全削除しない。
3. 実際の Debian ビルドに加え、新規 VM 作成、BIOS 読み込み、PCI / AGP、IDE、USB、ACPI、割り込みを必要に応じて確認する。
4. ソースや UI の変更を push する前に差分確認し、Actions 実行の可否はユーザーの指示に従う。
