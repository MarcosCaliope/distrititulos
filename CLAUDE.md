# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Rails 8 admin CRUD app for **Distrititulos**, a title/bond distribution system for a
cartório (Brazilian notary office) context — apresentantes (presenters), bancos (banks),
devedores (debtors), protests, and título (bond/note) tracking. The database schema
(`db/schema.rb`) is a large pre-existing legacy PostgreSQL schema (tables like
`cad_titulos`, `cad_protesto`, `tblremessas`, `smt_registro`, etc., all in Portuguese)
that was reverse-engineered into `db/schema.rb` — it was NOT built up through Rails
migrations, and there is no `db/migrate` directory. Only a small subset of the tables
currently have Rails models/controllers/views (`Apresentante`, `Banco`, `Devedor`); the
rest of the schema exists but is not yet modeled in the app.

When adding a model for one of the existing legacy tables, follow the pattern in
`app/models/*.rb`: set `self.table_name` and `self.primary_key` explicitly (composite
primary keys are common, e.g. `Devedor`'s `["tipo_doc", "cpf_cgc"]`), since table/column
names are fixed by the legacy schema and don't follow Rails conventions.

## Commands

```bash
bin/setup                          # install deps, prepare db, start server
bin/rails server                   # run the app
bin/rails console

bin/rails test                     # run unit/integration tests
bin/rails test:system              # run system tests (Capybara + headless Chrome)
bin/rails test test/models/foo_test.rb        # single file
bin/rails test test/models/foo_test.rb:12     # single test at line

bin/rubocop                        # lint (rubocop-rails-omakase style)
bin/rubocop -a                     # autocorrect
bin/brakeman                       # static security analysis
bin/importmap audit                # audit JS dependencies pulled via importmap
```

CI (`.github/workflows/ci.yml`) runs `brakeman`, `importmap audit`, `rubocop`, and
`bin/rails db:test:prepare test test:system` against a real Postgres service — no
mocking of the database layer.

## Database

- PostgreSQL only. The schema lives entirely in `db/schema.rb` (loaded via
  `db:schema:load` / `db:test:prepare`), not built from migrations.
- The schema declares a Postgres schema/namespace `distribuidor`
  (`create_schema "distribuidor"`) and several standalone sequences used as column
  defaults for legacy tables (e.g. `cax_lanc_id`, `smt_devedor_id_dev`) — these aren't
  tied to Rails-style serial/identity columns, so preserve them if you regenerate the
  schema dump.
- Development database connection is fully env-driven (`CENTRAL_DB_NAME`,
  `CENTRAL_DB_HOST`, `CENTRAL_DB_PORT`, `CENTRAL_DB_USER`, `CENTRAL_DB_PASSWORD`), with
  `CENTRAL_DB_NAME` defaulting to `central` — there's no hardcoded local dev database
  name (`config/database.yml`).
- Test database name is fixed: `distrititulos_test`.

## Architecture notes

- Standard Rails MVC, no API layer, no JS framework — server-rendered ERB views with
  Hotwire (Turbo/Stimulus) and Bootstrap 5 (loaded via CDN `<link>`/`<script>` tags in
  `app/views/layouts/application.html.erb`, not through the asset pipeline/importmap).
- Controllers follow a consistent CRUD shape (see `apresentantes_controller.rb`,
  `bancos_controller.rb`, `devedores_controller.rb`): `index` supports a `?q=` search
  param doing an `ILIKE` match against name/code columns, capped at `limit(50)`.
- Because some legacy models have composite primary keys, routes/finders can't rely on
  a single `:id`. See `Devedor`/`DevedoresController#set_devedor`, which joins the
  composite key with `Devedor.param_delimiter` for use in URLs.
