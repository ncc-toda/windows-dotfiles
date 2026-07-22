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

**Leader = `Ctrl+A`** を押してから次のキー（tmux 風）:

| キー | 動作 |
|---|---|
| `Shift+\|` | 横に分割 |
| `-` | 縦に分割 |
| `h` `j` `k` `l` | 左 / 下 / 上 / 右のペインへ移動 |
| `Shift+h/j/k/l` | ペインサイズ変更 |
| `z` | ペイン最大化トグル |
| `x` | ペインを閉じる（確認あり） |
| `c` | 新しいタブ（今のパスで開く） |
| `n` / `p` | 次 / 前のタブ |
| `1`〜`9` | その番号のタブへ |
| `Shift+S` | セッションを手動保存 |
| `r` | セッションを復元（ファジー選択） |

**Leader なし**の 1 ストローク:

| キー | 動作 | 注意 |
|---|---|---|
| `Ctrl+D` | 左右に分割 | シェルの EOF を奪う → 終了は `exit` か `Ctrl+A → x` |
| `Ctrl+Shift+D` | 上下に分割 | |
| `Ctrl+[` / `Ctrl+]` | 前 / 次のペインへ | `Ctrl+[` は Esc と同コード |
| `Ctrl+W` | ペインを即削除 | readline の単語削除を奪う |
| `Ctrl+T` | 新しいタブ | readline の transpose を奪う |
| `Ctrl+Shift+P` | コマンドパレット（全コマンド検索） | |

> セッション（タブ / ペイン / 開いていたパス）は 5 秒ごとに自動保存され、次回起動時に復元される。
> 終了時には保存されないので、確実に残すなら `Ctrl+A → Shift+S`。

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

## 5. エイリアス

| エイリアス | 実体 |
|---|---|
| `ls` | `eza --group-directories-first` |
| `ll` | `eza -l --git`（詳細 + git 状態） |
| `la` | `eza -la --git`（隠しファイルも） |
| `lt` | `eza --tree --level=2`（ツリー表示） |
| `cat` | `bat --paging=never`（色付き表示） |
| `..` / `...` | `cd ..` / `cd ../..` |
| `gs` | `git status` |
| `gd` | `git diff` |
| `gl` | `git log --oneline --graph --decorate -20` |

---

## 6. `just` コマンド（保守・開発用）

| コマンド | 動作 |
|---|---|
| `just` / `just switch` | 設定を適用（初回は既存 dotfiles を退避） |
| `just build` | 評価 / ビルドのみ（適用しない） |
| `just update` | nixpkgs / home-manager を最新化して適用 |
| `just upgrade` | dotfiles の中身を最新版に取り直して適用 |
| `just generations` | 世代一覧 / ロールバック |
| `just --list` | 全レシピを表示 |

---

## 7. 入っている CLI ツール

| ツール | 用途 |
|---|---|
| `eza` | `ls` の置き換え（アイコン / git 対応） |
| `bat` | `cat` の置き換え（色付き / 行番号） |
| `rg`（ripgrep） | 高速 grep |
| `fd` | 高速 find |
| `jq` / `yq` | JSON / YAML 整形 |
| `dust` / `duf` | `du` / `df` の見やすい版 |
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
