# Importação de arquivos de remessa

Porta do formulário legado VB6 `frmImpTitulos.frm`
(`D:\Fontes_SIAC_Andre\Projetos Smart\Distribuidor\fontes\frmImpTitulos.frm`) para a
aplicação Rails. Lê um arquivo de remessa de títulos para protesto (enviado por bancos/
apresentantes), valida a estrutura e grava os títulos, devedores, devedores solidários e o
histórico de remessa no banco.

## Onde fica

- `app/services/remessa_importer.rb` — toda a lógica de parsing/validação/gravação.
- `app/controllers/remessa_imports_controller.rb` — upload (`new`/`create`) e cancelamento
  de uma importação (`cancel`, GET mostra contagem, DELETE confirma e apaga).
- `app/views/remessa_imports/`
- Rotas: `resources :remessa_imports, only: %i[new create]` + `collection { get/delete :cancel }`
- Acesso pela UI: menu "Importar remessa" / aba "Processos" na home.

## Layout do arquivo

Texto de largura fixa, 600 posições por linha, 3 tipos de registro (posição 1):

- `0` = header (1 por arquivo, primeira linha)
- `1` = título (uma ou mais linhas por título — a primeira com posição 297 = `"1"` é o
  devedor principal; linhas seguintes com posição 297 ≠ `"1"` são devedores solidários do
  mesmo título)
- `9` = trailer (1 por arquivo, última linha)

Principais campos do registro tipo `1` (posições 1-based, como no VB `Mid(s, pos, len)`):

| Campo | Posição | Tamanho |
|---|---|---|
| Portador (banco) | 2 | 3 |
| Cedente | 20 | 45 |
| Sacador/credor | 65 | 45 |
| Doc. sacador | 110 | 14 |
| Endereço sacador | 124 | 45 |
| CEP sacador | 169 | 8 |
| Cidade sacador | 177 | 20 |
| UF sacador | 197 | 2 |
| Nosso número | 199 | 15 |
| Espécie (abrevia) | 214 | 3 |
| Número do título | 217 | 11 |
| Data emissão (DDMMAAAA) | 228 | 8 |
| Data vencimento | 236 | 8 |
| Valor (centavos) | 247 | 14 |
| Praça de pagamento | 275 | 20 |
| Flag titular/solidário | 297 | 1 |
| Nome devedor | 298 | 45 |
| Tipo doc devedor (`001`=CGC,`002`=CPF,outro=CI) | 343 | 3 |
| Doc. devedor | 346 | 14 |
| Endereço devedor | 371 | 45 |
| CEP devedor | 416 | 8 |
| Cidade devedor | 424 | 20 |
| UF devedor | 444 | 2 |
| Bairro devedor | 488 | 20 |
| Marca de falência | 566 | 1 |
| Sequencial da linha | 597 | 4 |

Header: portador (2,3), nº remessa (62,6), qtd registros transação (68,4), qtd títulos
(72,4), qtd indicações (76,4), qtd originais (80,4), agência centralizadora (84,6).
Trailer: portador (2,3), soma de segurança/quantidade (53,5).

Layout validado campo a campo contra um arquivo real de amostra
(`processados/B0010401.221`, 62 linhas) — todos os offsets conferem.

## Validações estruturais (abortam a importação inteira, nada é gravado)

1. Caractere não-ASCII (acentuado) em qualquer linha.
2. Sequencial da linha (posição 597-600) fora de ordem.
3. Primeira linha não é tipo `0`.
4. Apresentante/banco do header não cadastrado (`cad_bancos.codigo`/`codalfa` → `cd2` →
   `cad_apresenta.codigo`).
5. Linha do meio que não é tipo `1`, ou portador divergente do header.
6. Última linha não é tipo `9`, ou portador divergente do header.
7. Contagem de títulos/indicações/originais divergente do header.
8. Soma de segurança do trailer divergente.
9. Arquivo (mesmo nome) já importado antes.

## Validações por título (marcam irregular, não abortam)

`tipo_tit = "*"`, `icodirregularidade` e `stipoocorrencia = "5"` são gravados quando:
espécie não cadastrada em `cad_tipostit` (21) · CPF/CNPJ do devedor inválido (7) · CPF/CNPJ
do sacador inválido (10) · falta número do título (16) · endereço do devedor vazio/curto/sem
número (6) · data de emissão inválida (50) · data de vencimento inválida, no futuro, ou
emissão > vencimento (1) · nome do devedor igual ao cedente ou sacador (3) · documento do
devedor zerado (50) ou igual ao do credor (7) · [só linha titular] praça/cidade do devedor
diferente de "FORTALEZA" — exceto apresentante `073` (15) · [só linha titular] falência em
CPF (50). Se **várias** regras falharem no mesmo título, só o código da **última** que falhou
fica gravado (mesmo comportamento do VB original) — mas todas geram uma linha no log.
Descrições oficiais desses códigos: tabela própria `irregularidades` (não a
`distribuidor.irregularidades`, que pertence a outra aplicação — copiamos os 70 códigos de
lá uma única vez para termos uma tabela independente).

Dígito verificador de CPF/CNPJ: o código-fonte original (`DVCPF`/`DVCGC`) não estava no
projeto exportado, então usei os algoritmos padrão nacionais.

## O que é gravado

- **Linha titular**: garante o devedor em `cad_devedor` (cria se não existir, atualiza
  `sbairro` se já existir), gera `protocolo` novo via `nextval('seq_protocolo')` e insere em
  `cad_titulos`.
- **Linha solidária**: reaproveita o `protocolo` da última linha titular do mesmo arquivo,
  insere em `tbldevedorsolidario`; se ficar irregular, também marca o título principal
  (mesmo protocolo) como irregular.
- **Toda linha** (header, título, trailer): grava uma cópia em `tblremessas`.

## Diferença deliberada em relação ao original

O VB gravava linha a linha sem transação (uma falha no meio podia deixar dado parcial). A
versão Rails roda a importação inteira dentro de **uma transaction (tudo ou nada)**: se
qualquer validação estrutural falhar no meio do arquivo, nada fica gravado.

## Cancelar uma importação

Tela `/remessa_imports/cancel`: informa o nome do arquivo, mostra quantos títulos/remessas/
devedores solidários seriam apagados, exige digitar o nome do arquivo de novo para confirmar
(mesmo padrão de segurança do "excluir remessas por ano").

## Como foi testado

- `RemessaImporter` chamado dentro de uma transaction com `raise ActiveRecord::Rollback`
  proposital, usando o arquivo real `processados/B0010401.221`: 60 títulos importados
  (batendo com o header), 62 linhas gravadas em `tblremessas`, 6 títulos corretamente
  marcados irregulares. Confirmado no Postgres que nada ficou gravado após o rollback.
- Arquivo com contagem de header adulterada → importação abortada, 0 registros gravados.
- Fluxo HTTP completo (upload multipart, tela de erro, tela de cancelamento) testado só com
  o arquivo adulterado e consultas de contagem — nenhuma importação bem-sucedida foi
  executada de fato via HTTP, para não gravar dados reais sem autorização explícita.
