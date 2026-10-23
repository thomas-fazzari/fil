My personal RSS feed reader using [Miniflux](https://miniflux.app) with a small [Mojolicious](https://mojolicious.org) app.

```sh
mise install
mise run install
mise run hooks:install
mise run stack:up
mise run feeds:apply
mise run start
```

By default, it runs on <http://127.0.0.1:3000>, with Miniflux on <http://127.0.0.1:8080> (`admin` / `miniflux`).

`FIL_PORT`, `MINIFLUX_PORT`, `MINIFLUX_USERNAME` and `MINIFLUX_PASSWORD` change them, for example in the `[env]` of a parent `mise.toml`. Miniflux creates the admin on its first start only.

`FIL_FEEDS` points to the feeds file, where each table is a category, each key a feed URL and each value its settings, named as in the [Miniflux API](https://miniflux.app/docs/api.html). Root keys are user filters, and `Fil::Feeds` lists every supported setting.

`feeds:apply` deletes the feeds the file does not list, unless they have bookmarks.
