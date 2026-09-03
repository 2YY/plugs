# docs

`plugs`内の各プラグイン(dyn.pd, disp3rs3r.pd)の内部DSPを解説する[Livebook](https://livebook.dev/)ノートブック集です。説明文だけでなく、実際の`expr`/`expr~`式をElixirで再現し、実行して確認できる「ドキュメント兼テスト」になっています。

## 開き方

Livebookをインストールしていない場合:

```sh
mix escript.install hex livebook
```

インタラクティブに開く場合:

```sh
livebook server docs/dyn.livemd
livebook server docs/disp3rs3r.livemd
```

各ノートブックの最初のセルが`Mix.install`で必要な依存(`kino`, `vega_lite`, `kino_vega_lite`)を取得するので、`docs/`をMixプロジェクトとしてアタッチしなくても単体で動きます。

## 構成

- `mix.exs` / `.formatter.exs` — このディレクトリをElixirプロジェクトとして扱うための最小構成
- `dyn.livemd` — dyn.pd(Up/Downコンプレッサー)の解説
- `disp3rs3r.livemd` — disp3rs3r.pd(42段オールパス・フェイザー)の解説
