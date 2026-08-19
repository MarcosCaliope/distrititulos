# Importação de arquivos de remessa

Porta do formulário legado VB6 `frmImpTitulos.frm`
(`D:\Fontes_SIAC_Andre\Projetos Smart\Distribuidor\fontes\frmImpTitulos.frm`) para a
aplicação Rails. Lê um arquivo de remessa de títulos para protesto (enviado por bancos/
apresentantes), valida a estrutura e grava os títulos, devedores, devedores solidários e o
histórico de remessa no banco.

## Onde fica

- `app/services/remessa_importer.rb` — toda a lógica de parsing/validação/gravação.
- `app/jobs/remessa_import_job.rb` — roda o `RemessaImporter` em background (Active Job /
  Solid Queue) para não bloquear a requisição HTTP.
- `app/services/remessa_import_progress.rb` — guarda o estado da importação em andamento
  (`Rails.cache`, expira em 1h) e transmite as atualizações via Turbo Streams/Solid Cable
  para a tela aberta.
- `app/controllers/remessa_imports_controller.rb` — upload (`new`/`create`, que só enfileira
  o job e redireciona), acompanhamento (`show`) e cancelamento de uma importação (`cancel`,
  GET mostra contagem, DELETE confirma e apaga).
- `app/views/remessa_imports/`
- Rotas: `resources :remessa_imports, only: %i[new create show]` + `collection { get/delete :cancel }`
- Acesso pela UI: menu "Importar remessa" / aba "Processos" na home.

## Andamento em tempo real

`create` gera um `id` (`RemessaImportProgress.build_id`, um UUID), enfileira
`RemessaImportJob.perform_later(id, filename, content)` e redireciona para
`/remessa_imports/:id` — a requisição HTTP não fica bloqueada esperando o arquivo inteiro
processar. A página `show` abre uma stream Turbo (`turbo_stream_from "remessa_import_#{id}"`)
e renderiza o estado já salvo em cache (útil se a página for recarregada/reaberta no meio do
processamento).

Dentro do job, `RemessaImporter` recebe um `on_progress:` que é chamado a cada linha de log
(`grava_log`) com `processed`/`total` (linhas do arquivo). `RemessaImportProgress` usa isso
para: (1) regravar o estado no cache, (2) `broadcast_replace_to` a barra de progresso/resumo
(partial `_progress.html.erb`) e (3) `broadcast_append_to` a linha de log (partial
`_log_line.html.erb`) — quem estiver com a página aberta vê tudo ao vivo, sem recarregar.

Ao final, `RemessaImporter#call` também calcula `titulos_rejeitados_count` (títulos gravados
com `tipo_tit = "*"`, ou seja, marcados irregulares por alguma crítica) contando direto na
tabela após o commit — não dá pra somar isso durante o loop porque uma linha de devedor
solidário pode marcar como irregular um título que já tinha sido gravado como OK antes (ver
"O que é gravado" abaixo). O resumo final mostra título(s) importado(s) vs rejeitado(s).

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

## Validações

Lista completa (estruturais, que abortam a importação inteira, e por título, que só marcam o
título como irregular) em `docs/validacoes_importacao_remessas.md`. Resumo: 15 validações
estruturais (arquivo vazio, caractere não-ASCII, sequência de linhas, tipos de registro,
apresentante não cadastrado, empresa não cadastrada, arquivo já importado, contagens/soma de
segurança do header/trailer) e 11 validações por título (CPF/CNPJ do devedor e do sacador,
número do título, endereço, datas de emissão/vencimento, nome do devedor, praça/cidade, e
falência em CPF). Espécie não cadastrada não é uma crítica — é cadastrada automaticamente
(ver `docs/validacoes_importacao_remessas.md`). Descrições oficiais dos códigos de
irregularidade: tabela própria `irregularidades` (não a `distribuidor.irregularidades`, que
pertence a outra aplicação — copiamos os 70 códigos de lá uma única vez para termos uma
tabela independente).

O apresentante do header é localizado por `cad_apresenta.scodcompensacao` (não mais via
`cad_bancos`), e o `cad_titulos.cod_apr` gravado em cada título depende do município da
empresa (`cad_empresa`) — ver `docs/validacoes_importacao_remessas.md` para os detalhes de
ambos.

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
- Fluxo assíncrono (job + progresso ao vivo): testado via HTTP real (`curl`, servidor de
  dev já rodando) com um arquivo vazio, que falha em `validar_estrutura!` antes de qualquer
  `.create!` — confirma que `create` enfileira o job e redireciona, que o job roda e grava o
  estado em `Rails.cache`, e que `show` renderiza o log completo e o alerta de falha
  corretamente. `Titulo.count` conferido antes/depois (sem mudança) para garantir que nada
  foi gravado. `ActionCable` confirmado montado em `/cable` (handshake WS manual com `curl`).
  O caminho de sucesso (arquivo válido, títulos realmente gravados) não foi exercitado via
  HTTP pelo mesmo motivo do teste original — evitar gravar dados reais no banco de
  desenvolvimento, que é o banco de produção legado.
