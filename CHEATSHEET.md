# チートシート — windows-dotfiles

WSL (Ubuntu) + Windows + WezTerm 環境の**使い方・キーマップ・コマンド**をまとめた早見表。
1 枚で全体を見渡せるように、実際に配布される機能だけを載せてある。

> 詳細は [README.md](README.md) / [INSTALL.md](INSTALL.md) / [windows/README.md](windows/README.md) を参照。

---

## 1. インストール / 更新 / アンインストール

| やりたいこと | コマンド（PowerShell / WSL） |
|---|---|
| **入れる**（学生） | `irm https://raw.githubusercontent.com/ncc-toda/windows-dotfiles/v1.2/install.ps1 \| iex` |
| **dotfiles の中身を更新** | `just upgrade`（最新版 tarball を取り直して再適用） |
| **消す**（原状復帰） | `irm https://raw.githubusercontent.com/ncc-toda/windows-dotfiles/v1.2/uninstall.ps1 \| iex` |

配布は固定タグ **`v1.2`** から。`main` は開発版なので学生 URL には使わない。

---

## 2. WezTerm キーマップ（ペイン / タブ）

1 ストロークのキー:

| キー | 動作 | 注意 |
|---|---|---|
| `Ctrl+D` | 左右に分割 | シェルの EOF を奪う → 終了は `exit` |
| `Ctrl+Shift+D` | 上下に分割 | |
| `Ctrl+[` / `Ctrl+]` | 前 / 次のペインへ | `Ctrl+[` は Esc と同コード |
| `Ctrl+W` | ペインを即削除 | readline の単語削除を奪う |
| `Ctrl+T` | 新しいタブ | readline の transpose を奪う |
| `Ctrl+Shift+P` | コマンドパレット（全コマンド検索） | |

> セッション（タブ / ペイン / 開いていたパス）は 5 秒ごとに自動保存され、次回起動時に自動復元される。

---

## 3. Windows ホストのキー（AutoHotkey）

| キー | 動作 |
|---|---|
| **Caps Lock を素早く 2 回** | WezTerm を表示 / 非表示トグル（未起動なら起動） |
| **左 Shift 単押し** | 英数（IME OFF） |
| **右 Shift 単押し** | かな（IME ON） |

左右 Shift は Mac の「英数 / かな」と同じ**絶対切り替え**。他キーと同時押しなら通常の Shift として働く。

---

## 4. シェル操作（fzf / zoxide / yazi）

| キー / コマンド | 動作 |
|---|---|
| `z <名前>` | よく行くディレクトリへジャンプ（zoxide） |
| `zi` | 候補を対話選択してジャンプ |
| `Ctrl+R` | コマンド履歴をあいまい検索（fzf） |
| `Alt+C` | ディレクトリをあいまい検索して移動（fzf） |
| `y` | yazi（ファイラー）起動。終了時に居たディレクトリへ cd |
| `lazygit` | Git の TUI |

`cd` / `z` の直後は自動で `ls`（項目が 100 を超えると省略）。

> fzf のファイル検索（本来 `Ctrl+T`）は WezTerm が `Ctrl+T` を「新しいタブ」に割り当てているため使えない。
> ファイル挿入が必要なときは `**<Tab>`（fzf 補完）か yazi（`y`）を使う。

---

## 5. `just` コマンド（保守・開発用）

| コマンド | 動作 |
|---|---|
| `just` / `just switch` | 設定を適用（初回は既存 dotfiles を退避） |
| `just build` | 評価 / ビルドのみ（適用しない） |
| `just update` | nixpkgs / home-manager を最新化して適用 |
| `just upgrade` | dotfiles の中身を最新版に取り直して適用 |
| `just generations` | 世代一覧 / ロールバック |
| `just --list` | 全レシピを表示 |

---

## 6. 入っている CLI ツール

| ツール | 用途 |
|---|---|
| `rg`（ripgrep） | 高速 grep（yazi の内容検索にも使用） |
| `fd` | 高速 find（yazi の名前検索にも使用） |
| `btop` / `htop` | プロセスモニタ |
| `tree` | ディレクトリツリー |
| `yazi` | ファイラー TUI（`y` で起動） |
| `lazygit` | Git TUI |
| `gh` | GitHub CLI |
| `just` | コマンドランナー（`make` 代替） |
| `starship` | プロンプト |
| `zoxide` / `fzf` / `direnv` | ジャンプ / あいまい検索 / ディレクトリ別環境変数 |

---

### メモ

- **テーマ**は `kanagawabones`（Kanagawa 系）。カーソル色 = springBlue `#7fb4ca`。
- **フォント**は Fira Code Nerd Font（リガチャ + アイコン）。
- カスタマイズは `windows/wezterm.lua`（見た目 / キー）と `modules/`（シェル / CLI）を編集して `just switch`。
