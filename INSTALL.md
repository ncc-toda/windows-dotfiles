# インストール手順（学生向け）

ターミナル環境を**コマンド1つ**で入れます。所要 10〜20 分（ネットワーク次第）。

## 事前に必要なもの

- Windows 10/11 で **WSL が有効**（`Win + R` → `wsl` でエラーが出なければ OK）
- インターネット接続（学校のネットワークは GitHub を塞ぐことがあります → 自宅や別回線で）

## 入れる

1. **PowerShell** を開く（管理者でなくてよい）
2. 次の1行を貼って Enter:

   ```powershell
   irm https://raw.githubusercontent.com/ncc-toda/windows-dotfiles/release/install.ps1 | iex
   ```

3. 最初に「何を変更するか」が表示される → 読んで `y` で続行
4. 途中で聞かれること:
   - **どこに作るか** → 迷ったら **[1] 授業専用の WSL を新しく作る**（今の環境には一切触れません）
   - （新規作成を選んだ場合）**Linux のパスワード** → `sudo` に使います。忘れないもので
5. 「セットアップ完了」と出たら終わりです

## 使う

- **WezTerm** を起動 → 新しいシェルが開きます
- **Caps Lock を素早く2回** → WezTerm の表示 / 非表示
- **左 Shift** = 英数（IME OFF）、**右 Shift** = かな（IME ON）。Mac と同じ感覚です

キー操作の一覧は [`CHEATSHEET.md`](CHEATSHEET.md)。

## よくあるつまずき

| 症状 | 対処 |
|---|---|
| `winget がありません` | Microsoft Store で「アプリ インストーラー」を更新して再実行 |
| フォントが豆腐（□）になる | 学校のネットワークが GitHub を塞いでいます。別回線で `just switch` し直すか、[Nerd Fonts](https://www.nerdfonts.com/font-downloads) から Fira Code を手動導入 |
| Caps Lock 2回が効かない | WezTerm を一度起動してから試す。それでもダメなら再ログイン |
| `systemd が有効…` と言われた | 画面の指示どおり進めれば自動で有効化されます |
| スクリプトが実行できない | 先に `Set-ExecutionPolicy -Scope Process Bypass` を実行 |

## 設定を更新する

配布側が dotfiles を更新したら、WezTerm で:

```sh
cd ~/dotfiles && just upgrade
```

`just upgrade` は最新版を取り直して適用します（git は使いません）。手元で `~/dotfiles`
を編集しただけの反映なら `just switch` で足ります。

## 全部消す（元に戻す）

PowerShell で:

```powershell
irm https://raw.githubusercontent.com/ncc-toda/windows-dotfiles/release/uninstall.ps1 | iex
```

- 変更はすべて記録されているので、**元からあったファイルは復元**されます。
- **授業専用の WSL を作った場合**は丸ごと削除します（`-KeepDistro` で残せます）。
- WSL 内の **Nix は既定で残します**（他で使っている可能性のため）。消すなら
  `uninstall.ps1` を `-RemoveNix` 付きで実行、または WSL 内で `sudo /nix/nix-installer uninstall`。
