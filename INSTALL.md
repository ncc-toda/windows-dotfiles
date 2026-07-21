# インストール手順（学生向け）

ターミナル環境を **コマンド1つ** で入れます。所要 10〜20 分（ネットワーク次第）。

## 事前に必要なもの

- Windows 10/11 で **WSL が有効**（`ウィンドウ + R` → `wsl` でエラーにならなければ OK）
- インターネット接続（学校のネットワークだと GitHub が塞がれていることがあります。
  その場合は自宅や別回線で）

## 入れる

1. スタートメニューで **「PowerShell」** を開く（管理者でなくてよい）
2. 次の1行を貼り付けて Enter:

   ```powershell
   irm https://raw.githubusercontent.com/ncc-toda/windows-dotfiles/main/install.ps1 | iex
   ```

3. 最初に「何を変更するか」が表示されます。読んで `y` で続行。
4. 途中で聞かれること:
   - **どこに作るか**: 迷ったら **[1] 授業専用の WSL を新しく作る** を選んでください。
     今使っている環境には一切触りません。
   - （新規作成を選んだ場合）**Linux のパスワード**: `sudo` に使います。忘れないもので。
   - **git の名前とメール**（任意）: git で commit する人だけ。要らなければ
     **Enter でスキップ**できます。後から `~/dotfiles/local.nix` に書いて
     `just switch` すれば設定できます。
5. 「セットアップ完了」と出たら終わりです。

## 使う

- **WezTerm**（新しいターミナル）を起動 → 新しいシェルが開きます。
- **Caps Lock を素早く2回** → WezTerm が出る/引っ込む。
- **左 Shift** = 英数（IME OFF）、**右 Shift** = かな（IME ON）。Mac と同じ感覚です。

キー操作の一覧は [`windows/README.md`](windows/README.md) を参照。

## よくあるつまずき

| 症状 | 対処 |
|---|---|
| `winget がありません` | Microsoft Store で「アプリ インストーラー」を更新して再実行 |
| フォントが豆腐（□）になる | 学校のネットワークが GitHub を塞いでいます。別回線で `just switch` し直すか、[Nerd Fonts](https://www.nerdfonts.com/font-downloads) から Fira Code を手動導入 |
| Caps Lock 2回が効かない | WezTerm を一度起動してから試す。それでもダメなら再ログイン |
| `systemd が有効…` と言われた | 画面の指示どおり進めれば自動で有効化されます |
| スクリプトが実行できない | PowerShell で `Set-ExecutionPolicy -Scope Process Bypass` を先に実行 |

## 設定を更新する

配布側が設定（dotfiles の中身）を更新したら、WezTerm で:

```sh
cd ~/dotfiles && just upgrade
```

`just upgrade` は最新の dotfiles を取り直して適用します（git は使いません）。
手元で `~/dotfiles` を編集しただけの反映なら `just switch` で足ります。

## 全部消す（元に戻す）

PowerShell で:

```powershell
irm https://raw.githubusercontent.com/ncc-toda/windows-dotfiles/main/uninstall.ps1 | iex
```

- 変更はすべて記録されているので、**元からあったファイルは復元**されます。
- **授業専用の WSL を作った場合**は、それを丸ごと削除します（`-KeepDistro` で残せます）。
- WSL 内の **Nix はデフォルトでは残します**（他で使っているかもしれないため）。
  消すなら PowerShell で `& "$env:TEMP\...\uninstall.ps1" -RemoveNix`、または WSL 内で
  `sudo /nix/nix-installer uninstall`。
