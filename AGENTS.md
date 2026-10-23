# Dear Clanker

This repository contains **fil**, my personal RSS feed reader built on [Miniflux](https://miniflux.app).
Miniflux fetches and stores the feeds. A small [Mojolicious](https://mojolicious.org) app pushes the subscriptions from the feeds file to Miniflux and serves a minimal reader on top of its API.

## Layout

- The feeds file declares the subscriptions and the user filters. It lives outside the repository, at the path in `FIL_FEEDS`. `apply` deletes the Miniflux feeds it does not list.
- `compose.yaml` runs Miniflux and PostgreSQL. Miniflux listens on `127.0.0.1` only, on `MINIFLUX_PORT` or 8080.
- `lib/Fil.pm` is the app. `Fil::Miniflux` is the API client, `Fil::Feeds` reads the feeds file and `Fil::Sync` plans and applies changes.
- `lib/Fil/Command` holds the `plan` and `apply` commands of `script/fil.pl`.
- Unit tests live in `t`. The integration tests in `xt` need the running stack.

## Validation

Run the checks for the areas you changed before reporting work as done. `mise tasks --local` lists the project tasks.

| Change                                  | Command                                               |
| --------------------------------------- | ----------------------------------------------------- |
| Perl, templates, CSS, JS or tooling     | `mise run check`                                      |
| `Fil::Miniflux`, `Fil::Sync` or Compose | `mise run stack:up`, then `mise run test-integration` |

`mise run fix` fixes the formatting that `check` reports.

## Code

- Use `Mojo::Base` with `-signatures` in every module.
- Never give a controller action the name of a helper. The action shadows the helper, and calling it from the action recurses forever.
- Keep the reader server-rendered. Turbo handles links and forms, and `public/js` only holds what HTML cannot do. Ask before adding a script.
- Name feed settings as the Miniflux API does, so `Fil::Sync` can send them unchanged.
- Write almost no comments. Add one only for a constraint the code cannot show, in one line.
- Change only what the task needs. Report unrelated problems instead of fixing them.

## Prose

- Short sentences and common words.
- Avoid semicolons, em dashes, filler and repeated facts.
