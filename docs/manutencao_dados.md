# Manutenções de dados

Registro de operações executadas diretamente no banco (fora do controle de versão, já que
não são mudanças de código/schema versionadas por migration — este app usa `db/schema.rb`
reverso-engenheirado, sem migrations).

## 2026-08-15 — Preenchimento de `cad_apresenta.scodcompensacao`

Contexto: campo `scodcompensacao` foi adicionado em `cad_apresenta` (ver commit
`a2e581f`, "Add new fields to cad_apresenta") mas ficou vazio para os registros já
existentes. Preenchido em duas passadas a partir de `cad_bancos`, usando a relação
`cad_bancos.cd2 = cad_apresenta.codigo` (o mesmo relacionamento já usado em
`GetApresentante`/`BuscaApresentante` no processo de importação de remessas, ver
`docs/importacao_remessas.md`).

**Passada 1 — código numérico do banco:**

```sql
UPDATE cad_apresenta a
SET scodcompensacao = b.codigo
FROM (
  SELECT cd2, MIN(codigo) AS codigo
  FROM cad_bancos
  WHERE cd2 IS NOT NULL AND trim(cd2) <> ''
  GROUP BY cd2
) b
WHERE a.codigo = b.cd2;
```

4.742 apresentantes atualizados. 16 apresentantes tinham mais de um banco com o mesmo `cd2`
(em parte por formatação diferente do mesmo código, ex: `000995` vs `995`; em parte bancos
genuinamente diferentes) — nesses casos, usado o menor `codigo` (`MIN`, ordem lexicográfica),
por decisão explícita do usuário.

**Passada 2 — código alfanumérico do banco (sobrescreve a passada 1 onde existir):**

```sql
UPDATE cad_apresenta a
SET scodcompensacao = b.codalfa
FROM cad_bancos b
WHERE a.codigo = b.cd2
  AND b.codalfa IS NOT NULL AND trim(b.codalfa) <> '';
```

1.922 apresentantes atualizados (substituindo o valor numérico da passada 1 pelo
alfanumérico, já que `codalfa` é a identificação preferencial quando existe). Sem
ambiguidade de `cd2` duplicado nesse subconjunto.

**Resultado final:** apresentantes cujo apresentante correspondente em `cad_bancos` tem
`codalfa` preenchido ficam com o código alfanumérico; os demais (sem `codalfa`) ficam com o
código numérico da passada 1; apresentantes sem nenhum banco com `cd2` correspondente
permanecem com `scodcompensacao` vazio.
