# Distrititulos

Sistema de distribuição de títulos para protesto (Cartório/Fortaleza-CE). Aplicação Rails 8
sobre um banco Postgres legado — a mesma base de dados usada há anos por um sistema desktop
em VB6, agora também acessada por esta aplicação web.

## Contexto do banco de dados

O schema é legado, reverso-engenheirado em `db/schema.rb` (não há migrations). As tabelas
principais usam nomes/convenções antigos (`cad_*`, `tbl*`), muitas com chave primária
composta e colunas de largura fixa. Os models Rails mapeiam essas tabelas explicitamente
via `self.table_name`/`self.primary_key` — ver `CLAUDE.md` para detalhes de arquitetura.

O banco também contém um schema separado (`distribuidor`) pertencente a **outra aplicação**
Rails independente que roda no mesmo Postgres — esta aplicação não usa esse schema (exceto
por uma cópia pontual e única de dados de referência, ver `docs/manutencao_dados.md`).

## Funcionalidades

### Cadastros (dados de referência)
Apresentantes, Bancos, Devedores, Devedores solidários, Distribuidores, Espécies, Faixas,
Protestos, Tipos de documento, Tipos de título, Atos, Feriados, Irregularidades — CRUD
padrão (listar com busca, ver, criar, editar, remover) para cada um.

### Processos
- **Títulos** — a tabela central do sistema (títulos levados a protesto). Busca por
  protocolo/número, CPF-CNPJ, nome do devedor, data de recebimento/distribuição e valor
  aproximado.
- **Remessas** — histórico de linhas de arquivos de remessa importados. Inclui exclusão em
  massa por ano (com confirmação em duas etapas).
- **Importar remessa** — porta do processo de importação do sistema legado (lê um arquivo de
  remessa de largura fixa enviado por bancos/apresentantes, valida a estrutura e grava
  títulos/devedores/devedores solidários/remessas). Detalhes completos em
  `docs/importacao_remessas.md`.

## Rodando localmente

```bash
bin/setup          # instala dependências, prepara o banco, sobe o servidor
bin/rails server    # só subir o servidor
bin/rails test      # testes
bin/rubocop         # lint
```

A conexão de desenvolvimento é via variáveis de ambiente (`CENTRAL_DB_*`), carregadas de um
`.env.development` local (não versionado) via `dotenv-rails`. Ver `CLAUDE.md` para os
detalhes de configuração deste ambiente específico.

## Documentação adicional

- `CLAUDE.md` — arquitetura e comandos, voltado para trabalhar no código (humano ou agente).
- `docs/importacao_remessas.md` — layout do arquivo de remessa, regras de validação e o que
  é gravado em cada tabela.
- `docs/manutencao_dados.md` — operações de manutenção de dados executadas diretamente no
  banco (fora do controle de versão).

## Notas de performance

Algumas tabelas são grandes (`cad_titulos` ~5,7M linhas, `tblremessas` ~2,45M linhas) e o
banco usa uma collation que impede o uso de índice em buscas `LIKE`/`ILIKE` por trecho —
por isso a busca nessas telas é limitada a igualdade exata ou faixas em colunas indexadas,
com um `statement_timeout` de segurança onde ainda resta risco (nome do devedor em Títulos).
Antes de adicionar um novo filtro de busca numa tabela grande, vale testar o plano de
execução (`EXPLAIN ANALYZE`) antes de assumir que vai ser rápido.
