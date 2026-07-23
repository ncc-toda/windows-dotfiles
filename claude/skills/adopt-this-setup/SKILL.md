---
name: adopt-this-setup
description: 配布された windows-dotfiles 環境を「自分のベース」にするための初期設定を対話で行う。git の名前/メールなどマシン固有の設定を ~/dotfiles/local.nix にだけ安全に書き込み、`just switch` で反映する。利用者が「この環境を自分のものにしたい」「初期設定したい」「git の名前(メール)を設定したい」等と言ったら使う。
---

# adopt-this-setup

配布された **windows-dotfiles** 環境を、利用者自身のものとして初期設定するための手順です。

## 前提となるモデル(重要 — 逸脱しないこと)

- このマシンの `~/dotfiles` は配布物(tarball 展開)で、**再インストール(更新)で上書きされ得る**。
- **永続する個人設定を書いてよいのは `~/dotfiles/local.nix` だけ**。`scripts/setup.sh` は再実行時に `local.nix` を残す(tarball には含まれないため)。
- したがってこの skill は **`local.nix` のみ**を編集する。`modules/*.nix` などの追跡ファイルは**編集しない**(更新で消え、設定が失われるため)。
- `username` と `homeDirectory` は「実際のログインユーザー」の真実。**絶対に変更しない**。ここを書き換えると `just switch` が最後に失敗する。

## 手順

1. **現状確認**: `~/dotfiles/local.nix` を読む。`username` / `homeDirectory` と、既存の `git` ブロックの有無を把握する。
2. **聞き取り**: コミットに刻む git の名前とメールアドレスを尋ねる。
   - 任意であること、GitHub を使うなら GitHub 側と揃えると良いことを伝える。
   - 設定不要ならこの skill は何もせず終えてよい。
3. **書き込み**: `local.nix` の属性セットに `git = { name = "..."; email = "..."; };` を追加/更新する。
   - `username` / `homeDirectory` の行は触らない。
   - 名前とメールの **両方が揃ったときだけ** git ブロックを書く(`modules/git.nix` は両方揃ったときのみ `user.*` を設定する)。片方だけなら書かない。
   - 身元不要なら git ブロックは書かない(既にあれば削除してよい)。
4. **反映**: `cd ~/dotfiles && just switch` を実行して適用する。エラーが出たら `local.nix` が正しい nix の属性セット(各行末に `;`、文字列は `"..."`)になっているか確認する。
5. **確認**: `git config user.name` と `git config user.email` を実行して反映を確認し、結果を利用者へ報告する。

## 参考: local.nix の形

```nix
{
  username = "student";          # 変更しない
  homeDirectory = "/home/student"; # 変更しない
  git = {
    name = "Your Name";
    email = "you@example.com";
  };
}
```

## 今後拡張できること(現時点では未対応)

エディタ・テーマ・その他の個人設定は、まだ `local.nix` のスキーマに無いため、この skill では設定できない。対応するには **repo 側**で `local.nix` のキーと、それを読む `modules/*.nix` を増やす必要がある(= 配布メンテナの作業)。利用者にはそう説明し、**このマシンの `modules/*.nix` を書き換えて対応しようとしないこと**(更新で消えるため)。
