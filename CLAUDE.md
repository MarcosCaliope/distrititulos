# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Distrititulos**, a Rails 8 admin app for a cartório (Brazilian notary office, Fortaleza-CE)
that manages títulos (bonds/notes) taken to protest. It runs on a legacy PostgreSQL database
that has been in production for years under a desktop VB6 system, and is now also read/written
by this web app. The schema (`db/schema.rb`) was reverse-engineered from that legacy database
— it was NOT built up through Rails migrations, and there is no `db/migrate` directory. Table
and column names are old and in Portuguese (`cad_titulos`, `cad_protesto`, `tblremessas`,
`tbldevedorsolidario`, etc.), many with fixed-width columns and composite primary keys.

Cadastros (reference data) with standard CRUD (index w/ search, show, new/edit, destroy):
Apresentantes, Bancos, Devedores, Devedores solidários, Distribuidores, Empresas, Espécies,
Faixas, Protestos, Tipos de documento, Tipos de título, Atos, Feriados, Irregularidades.

Processos (the actual business workflow):
- **Títulos** (`cad_titulos`, ~5.7M rows) — the central table, títulos taken to protest.
- **Remessas** (`tblremessas`, ~2.45M rows) — history of every line from imported remessa files.
- **Importar remessa** — ports the legacy VB6 import (`frmImpTitulos.frm`): parses a
  fixed-width remessa file sent by a bank/apresentante, validates it, and writes
  títulos/devedores/devedor_solidarios/remessas. See "Remessa import" below and
  `docs/importacao_remessas.md`.

When adding a model for one of the still-unmapped legacy tables, follow the pattern in
`app/models/*.rb`: set `self.table_name` and `self.primary_key` explicitly. Composite primary
keys are common (e.g. `Devedor`'s `["tipo_doc", "cpf_cgc"]`, `Remessa`'s
`["codapr", "snomearquivotexto", "isql"]`) — this uses Rails 8's native composite primary key
support, which gives the model a `param_delimiter` class method. Controllers for these models
join the key with it to build/parse the `:id` param (see `DevedoresController#set_devedor`,
`RemessasController#set_devedor`); routes for them need `constraints: { id: /.+/ }` since the
joined key contains the delimiter (see the `:remessas` route).

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
`bin/rails db:test:prepare test test:system` against a real Postgres service — no mocking of
the database layer. Note `test/` currently has no actual test files (only `.keep`
placeholders), so there's no existing test to pattern-match against yet.

## Database

- PostgreSQL only. The schema lives entirely in `db/schema.rb` (loaded via
  `db:schema:load` / `db:test:prepare`), not built from migrations.
- The schema declares a Postgres schema/namespace `distribuidor`
  (`create_schema "distribuidor"`) that belongs to a **separate, independent Rails app**
  sharing the same Postgres instance — this app does not use it, except for one deliberate
  one-time copy of reference data (`irregularidades`, see `docs/manutencao_dados.md`). Also
  present: several standalone sequences used as column defaults for legacy tables (e.g.
  `cax_lanc_id`, `smt_devedor_id_dev`, `seq_protocolo`) that aren't tied to Rails-style
  serial/identity columns — preserve them if you regenerate the schema dump.
- Development database connection is fully env-driven (`CENTRAL_DB_NAME`, `CENTRAL_DB_HOST`,
  `CENTRAL_DB_PORT`, `CENTRAL_DB_USER`, `CENTRAL_DB_PASSWORD`), loaded from a local
  `.env.development` (not versioned, via `dotenv-rails`), with `CENTRAL_DB_NAME` defaulting to
  `central` — there's no hardcoded local dev database name (`config/database.yml`).
- Test database name is fixed: `distrititulos_test`.
- Data-only maintenance done directly on the database (not expressible as a versioned
  migration, since there are none) is logged in `docs/manutencao_dados.md` — check it before
  assuming a column's historical values are consistent.

## Architecture notes

- Standard Rails MVC, no API layer, no JS framework — server-rendered ERB views with
  Hotwire (Turbo/Stimulus) and Bootstrap 5 (loaded via CDN `<link>`/`<script>` tags in
  `app/views/layouts/application.html.erb`, not through the asset pipeline/importmap).
- Controllers follow a consistent CRUD shape (`index`/`show`/`new`/`create`/`edit`/`update`/
  `destroy`), one per cadastro/processo table.
- **Search pattern depends on table size**, because the Postgres collation in use prevents
  index usage on `LIKE`/`ILIKE`, even prefix-only:
  - Small cadastro tables (`apresentantes`, `bancos`, `devedores`, ...): `index` does an
    `ILIKE` match against name/code columns via `?q=`, capped at `limit(50)`.
  - Large tables (`cad_titulos` ~5.7M rows, `tblremessas` ~2.45M rows,
    `titulos_controller.rb`/`remessas_controller.rb`): filters are restricted to exact-match
    equality on indexed columns (protocolo, num_tit, cpf_cgc, codapr, dates, ...), since any
    filter on a non-indexed column can force a near-full-table scan. `devedor` (name) on
    Títulos is the one exception that still needs substring search, so it's wrapped in a
    `SET LOCAL statement_timeout` inside a transaction to turn a runaway query into a friendly
    error instead of a hang. **Before adding a new filter to a large table**, check
    `EXPLAIN ANALYZE` rather than assuming it'll be fast — see the comments in
    `titulos_controller.rb`/`remessas_controller.rb` for the full reasoning.
- **Bulk destructive operations require typed confirmation**: `RemessasController#purge`
  (delete all remessas from a year and earlier) and `RemessaImportsController#cancel` (undo an
  entire remessa import) both do a `GET` that previews the affected row count, then only
  execute on `DELETE` if the user retypes the year/filename as confirmation. Follow this
  two-step pattern for any other bulk/irreversible delete.
- **Remessa import** (`app/services/remessa_importer.rb`) is a plain service object (not a
  model/job) that ports `frmImpTitulos.frm` from the legacy VB6 system: parses a 600-column
  fixed-width file, runs structural validations that abort the whole import (nothing is
  written) if they fail, then per-título validations ("críticas") that don't abort — they just
  mark that título irregular (`tipo_tit = "*"`, `icodirregularidade` set) and keep going, same
  as the original. One exception: an unknown espécie is auto-created in `cad_especie` rather
  than triggering a crítica. The apresentante of the header is located via
  `cad_apresenta.scodcompensacao`, and the `cad_titulos.cod_apr` written for each título
  depends on the município of `cad_empresa`. Everything is wrapped in one
  `ActiveRecord::Base.transaction` (a deliberate change from the original, which wrote
  row-by-row with no transaction). Full field layout and what gets written are documented in
  `docs/importacao_remessas.md`; the complete validation list (structural + per-título) and
  irregularidade codes are in `docs/validacoes_importacao_remessas.md` — read both before
  touching this service, since the fixed-width offsets and validation order both need to stay
  byte-for-byte compatible with the legacy format.
