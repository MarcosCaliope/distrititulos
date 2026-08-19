# Validações da importação de remessa

Detalha cada validação feita por `RemessaImporter` (`app/services/remessa_importer.rb`) ao
importar um arquivo de remessa, na ordem em que são checadas no código. Ver
`docs/importacao_remessas.md` para o layout do arquivo e o que é gravado no banco.

Há dois grupos, com efeito bem diferente:

- **Estruturais** — sobre o arquivo como um todo. Se qualquer uma falhar, a importação inteira
  é abortada dentro de uma transaction: nada é gravado no banco.
- **Por título** ("críticas") — sobre um título individual. Não abortam nada; o título é
  apenas marcado como irregular (`tipo_tit = "*"`, `stipoocorrencia = "5"`,
  `icodirregularidade` = código da regra) e a importação continua normalmente.

## Validações estruturais

Checadas em `validar_estrutura!`, nesta ordem:

1. **Arquivo vazio** — nenhuma linha após remover linhas em branco.
2. **Caractere não-ASCII** — qualquer byte > 127 em qualquer linha (acentos não são aceitos,
   igual ao sistema original).
3. **Sequencial fora de ordem** — posição 597–600 de cada linha deve ser igual ao número da
   linha (1, 2, 3, ...).
4. **Primeira linha não é header** — posição 1 da primeira linha deve ser `"0"`.
5. **Apresentante não cadastrado** — código de compensação do header (posição 2–4) precisa
   resolver para um `Apresentante` cujo `cad_apresenta.scodcompensacao` seja igual a esse
   código (ver [Como o apresentante é localizado](#como-o-apresentante-é-localizado) abaixo).
6. **Empresa não cadastrada** — precisa existir uma linha em `cad_empresa` (usada para decidir
   o valor de `titulo.cod_apr`, ver abaixo). Sem isso a importação não roda.
7. **Arquivo já importado** — já existe alguma `Remessa` com esse `snomearquivotexto`. (É essa
   verificação que a tela de "cancelar importação" existe para reverter.)
8. **Linha do meio não é tipo `1`** — toda linha entre a primeira e a última deve ser um
   registro de título/transação.
9. **Portador divergente (transação)** — posição 2–4 de uma linha do meio diferente do
   portador do header.
10. **Última linha não é trailer** — posição 1 da última linha deve ser `"9"`.
11. **Contagem de títulos divergente** — quantidade de linhas titulares (posição 297 = `"1"`)
    diferente do valor declarado no header (posição 72–75).
12. **Contagem de indicações divergente** — dentre os títulos, quantos têm espécie em
    `DMI`/`DRI`/`CBI` (posição 214–216), comparado ao header (posição 76–79).
13. **Contagem de originais divergente** — o restante dos títulos (não-indicação), comparado
    ao header (posição 80–83).
14. **Portador divergente (trailer)** — posição 2–4 do trailer diferente do portador do
    header.
15. **Soma de segurança divergente** — posição 53–57 do trailer deve ser igual a
    `qtd_transacao + qtd_titulos + qtd_indicacoes + qtd_originais`.

## Como o apresentante é localizado

`RemessaImporter#resolver_apresentante` busca `Apresentante.find_by(scodcompensacao:
codigo_compensacao)`, onde `codigo_compensacao` é a posição 2–4 do header (código numérico ou
alfanumérico do banco/apresentante). `cad_apresenta.scodcompensacao` já é o código de
compensação resolvido para cada apresentante (numérico ou `codalfa`, o que existir — ver
`docs/manutencao_dados.md`), então essa é uma busca direta, sem passar por `cad_bancos`.

## `titulo.cod_apr`

O valor gravado em `cad_titulos.cod_apr` depende do município da empresa (`cad_empresa`,
única linha, ver `docs/manutencao_dados.md`/CRUD de Empresas):

- Se `cad_empresa.scodmunicipio` for `"2304400"` (código IBGE de Fortaleza-CE — o município da
  própria empresa) — `cod_apr` recebe `apresentante.codigo`.
- Em qualquer outro município — `cod_apr` recebe `apresentante.scodcompensacao`.

Calculado uma única vez por arquivo (a partir do apresentante do header), não por título.

## Espécie (não é uma crítica)

A espécie (abreviação na posição 214–216) **não marca o título irregular** quando não está
cadastrada em `cad_tipostit` — diferente de todas as validações por título abaixo. Em vez
disso, `RemessaImporter#criar_tipo_tit` cadastra a espécie na hora: cria um `TipoTit` novo com
`abrevia` igual ao valor do arquivo e `codigo` igual ao maior `codigo` numérico já cadastrado
mais 1 (códigos não numéricos, como as letras usadas em alguns registros antigos, são
ignorados nesse cálculo). O título usa o `codigo` desse registro (novo ou existente)
normalmente, com `icodirregularidade = 0`.

## Validações por título

Checadas em `avaliar_criticas` para cada linha de título (titular ou solidária). O código
entre parênteses é o `icodirregularidade` gravado; a descrição oficial de cada código vive na
tabela `irregularidades`. **Se mais de uma regra falhar no mesmo título, só o código da
última que falhou é gravado** (mesmo comportamento do VB original) — mas todas geram uma
linha no log de importação.

| Código | Condição |
|---|---|
| 7 | CPF/CNPJ do devedor (posição 346–359) inválido pelo dígito verificador padrão — exceto quando o documento é exatamente `00000000000000`, caso em que o código gravado é 50 em vez de 7. Documentos do tipo `CI` (nem CPF nem CGC) nunca falham essa checagem, independente do conteúdo — igual ao original, que só valida dígito verificador de CPF/CNPJ. |
| 10 | CPF/CNPJ do sacador (posição 110–123) inválido. |
| 16 | Número do título (posição 217–227) vazio. |
| 6 | Endereço do devedor (posição 371–415) vazio, ou com menos de 5 posições (no campo bruto, sem remover espaços — na prática só pega linha truncada, já que o campo de largura fixa normalmente vem preenchido com espaços até 45 posições), ou sem nenhum dígito e sem "SN"/"S/N"/"S?N" em nenhum lugar da string (válido se tiver um dígito OU o marcador "sem número"). |
| 50 | Data de emissão (posição 228–235, `DDMMAAAA`) inválida ou anterior a 1900-01-01 — nesse caso a data é forçada para 1900-01-01. |
| 50 | Data de vencimento (posição 236–243) inválida (não é `DDMMAAAA` parseável nem um dos códigos especiais `99999999`/`99990001`/`99990030`) — nesse caso a data é forçada para a data de emissão. |
| 1 | Data de vencimento no futuro (maior que hoje) ou anterior à data de emissão. |
| 3 | Nome do devedor (posição 298–342) igual ao nome do cedente (posição 20–64) ou ao nome do sacador (posição 65–109). |
| 7 | Documento do devedor igual ao documento do sacador. |
| 15 | *(só na linha titular)* Praça de pagamento (posição 275–294) diferente de "FORTALEZA" — exceto para o apresentante `073`. |
| 15 | *(só na linha titular)* Cidade do devedor (posição 424–443) diferente de "FORTALEZA" — exceto para o apresentante `073`. |
| 50 | *(só na linha titular)* Tipo de documento do devedor é CPF e a marca de falência (posição 566) é `"F"` (CPF não pode ser protestado para fins falimentares). |

Dígito verificador de CPF/CNPJ: o código-fonte original (`DVCPF`/`DVCGC`) não estava
disponível, então `RemessaImporter#cpf_valido?`/`#cnpj_valido?` implementam os algoritmos
padrão nacionais (módulo 11) em vez de portar o cálculo original.
