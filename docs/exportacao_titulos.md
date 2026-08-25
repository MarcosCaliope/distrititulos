# Exportação de títulos

Porta do formulário legado VB6 `frmExportaTitulos.frm`
(`D:\Fontes_SIAC_Andre\Projetos Smart\Distribuidor\fontes\frmExportaTitulos.frm`) para a
aplicação Rails. Gera, para uma data de distribuição, um arquivo de remessa de exportação de
largura fixa (mesmo esquema de 600 posições/linha da importação, ver
`docs/importacao_remessas.md`) por cartório de protesto × apresentante, e envia esses arquivos
por e-mail para cada cartório. Existem outros arquivos `frmExportaTitulosProtesto*.frm` no
mesmo diretório do legado, mas são uma variante antiga (Access/MDI, não usa
`conexaoPtg`/Postgres) — não são a tela em uso hoje, então não fazem parte deste port.

## Onde fica

- `app/services/exportador_titulos.rb` — toda a geração dos arquivos (equivalente ao botão
  "Exportar"/`cmdImportar_Click` do formulário legado).
- `app/models/tbl_arquivo.rb` — mapeia `tblarquivos`, o registro de cada arquivo gerado.
- `app/models/cfg_contador.rb` — mapeia `cfg_contadores`, só lido (para o valor de custas
  padrão, `ps_titulo_digital` do `id_co = 2`).
- `app/mailers/exportacao_mailer.rb` — envia os arquivos gerados por e-mail (equivalente ao
  botão "Enviar Email"/`cmdEmail_Click`).
- `app/controllers/exportacoes_controller.rb` — `new`/`create` (gera os arquivos) e
  `enviar_email` (envia por e-mail os arquivos já registrados em `tblarquivos` numa data, sem
  regerar nada).
- `app/views/exportacoes/`, `app/views/exportacao_mailer/`.
- Rotas: `resources :exportacoes, only: %i[new create]` + `collection { post :enviar_email }`.
- Acesso pela UI: menu "Exportação de títulos" / aba "Processos" na home.

## O que o formulário legado fazia

O form tinha um campo de data (de distribuição) e um campo `txtComp` com três modos:

- Um código de compensação de apresentante específico.
- `"T"` — todos os apresentantes que tiveram títulos distribuídos na data (`BuscaApres`).
- `"0"` — títulos avulsos/digitados diretamente no sistema (`status = 'G'`, sem remessa de
  importação original).

O botão "Exportar" então, para cada apresentante do modo escolhido × cada `cad_protesto` ativo:
abre um arquivo, grava uma linha header ("0"), uma linha "1" por título (mais uma por devedor
solidário) e uma linha trailer ("9"), e registra o arquivo gerado em `tblarquivos`. Um botão
separado, "Enviar Email", varre `tblarquivos` da data e manda os arquivos por e-mail para cada
`cad_protesto.pro_email`/`scopiaemail`.

Título **não-avulso**: a linha de detalhe relê a linha original importada
(`tblremessas.sregistro`, pela chave `codapr+snomearquivotexto+isql` do próprio título) e
reaproveita a maior parte dos campos por posição — só recalcula cartório, protocolo, tipo de
ocorrência, data de ocorrência, irregularidade e sequencial. Se a linha original não existir
mais, a linha de detalhe não é escrita — mas o título ainda entra nas contagens do header
(mesmo comportamento do legado, preservado).

Título **avulso**: a linha de detalhe é montada direto de `cad_titulos`/`cad_devedor`, sem
nenhuma linha original pra reler.

### Mudanças deliberadas em relação ao legado

- **Apresentante em vez de banco**: o legado localiza o apresentante e a pasta de depósito via
  `cad_bancos.cd2`. Esta versão localiza via `cad_apresenta.scodcompensacao` — mesma mudança já
  feita no lado da importação (`RemessaImporter`, ver `docs/importacao_remessas.md`).
- **Tipo de título excluído configurável**: o legado sempre filtra `tipo_tit <> '*'`
  (hardcoded) nas consultas que selecionam títulos para exportar. Esta versão usa
  `cad_empresa.stipotitpadraodev`, caindo em `"*"` se o campo estiver vazio. A única exceção é
  a decisão de **imprimir a irregularidade** dentro da linha de detalhe (`GeraDetalhe`/
  `GeraSolidario`), que no legado sempre comparava com o literal `"*"` — isso foi preservado
  como está: se o tipo excluído configurado for diferente de `"*"`, um título com
  `tipo_tit = "*"` pode passar pelo filtro (porque não é o tipo configurado) e ainda assim
  imprimir a irregularidade nessa posição, exatamente como o código original faria.
- **Pasta de depósito com fallback**: o legado sempre grava na pasta de `cad_bancos.deposito`.
  Esta versão usa `cad_empresa.spathdeposito` se estiver preenchido; senão, cai no novo campo
  `cad_apresenta.sdeposito` (varchar 150, mesmo padrão dos campos `spath*` de `cad_empresa`,
  criado direto no banco via `ALTER TABLE`, sem migration).
- **Divisão por quantidade de títulos**: quando `cad_empresa.iquantidadetitporremessa` está
  preenchido (> 0), a lista de títulos de cada cartório×apresentante (ou avulso) é dividida em
  fatias desse tamanho — cada fatia vira um arquivo próprio, com header/trailer recalculados só
  para aquela fatia. Quando vazio, gera um arquivo só (comportamento do botão "Exportar"
  principal). Isso substitui a finalidade de duas partes do legado que **não foram portadas**:
  a tela irmã "Exportar Rem Grande" (`cmdExpEspecia_Click`, que evitava arquivos grandes demais
  dividindo por remessa de importação original) e um bloco de código morto/comentado
  (`cmdImportar_Click`, linhas ~713-727) que tentava dividir por contagem de sequencial.
- **Não replica o filtro `bngera`** do modo "T": o legado pulava apresentantes com
  `cad_bancos.bngera = true` em `BuscaApres`; não existe campo equivalente em `cad_apresenta`
  hoje, então o modo "T" processa todos os apresentantes com títulos distribuídos na data.
- **Simplificação no título avulso**: quando `cad_devedor` não é encontrado para a pessoa da
  linha, o legado pula um conjunto de campos diferente para a linha titular (só endereço/CEP/
  cidade/UF) e para cada linha de devedor solidário (nome/documento/RG também, além desses
  quatro). Esta versão usa a mesma regra pras duas: só endereço/CEP/cidade/UF ficam de fora.
- **`tblarquivos.dist_id`**: sempre gravado como `"0"` no legado (comentário no código original:
  a seleção por distribuidor foi removida do filtro, títulos dos dois distribuidores entram no
  mesmo arquivo). Como um lote agora pode virar mais de um arquivo (divisão por quantidade), e a
  chave primária de `tblarquivos` não tem espaço para um índice de fatia, `dist_id` foi
  reaproveitado como esse índice (`"0"`, `"1"`, `"2"`, ...) — o passo de e-mail não filtra por
  `dist_id`, então isso não muda quais arquivos são anexados.
- **Acentos em campos avulsos**: campos de título avulso vêm direto de colunas de texto
  digitadas (`cedente`, `sendsacador`, nome do devedor, endereço, bairro, ...), que podem ter
  acento. Como a linha final precisa ter exatamente 600 **bytes**, esses campos (só esses — não
  os relidos de `tblremessas.sregistro`, que são preservados byte a byte) passam por
  transliteração pra ASCII antes de entrar na linha.

## Nome do arquivo e cabeçalho/trailer

Mesma convenção do legado: `"D" + no_portador(3) + ddmm(4) + ext`, onde `no_portador` é o
`cad_apresenta.scodcompensacao` do apresentante (`cod_apr`), formatado em 3 posições — zero à
esquerda se for só dígitos (`campo_numerico`), senão alinhado à esquerda (`campo_string`).
Conferido contra um arquivo real gerado pelo sistema legado (`D0Y52508.2622`, apresentante com
`scodcompensacao = "0Y5"`): o código do portador é usado como está, sem reformatação — não é
relido de `tblremessas.sregistro` (posição 2-4 do header/detalhe/trailer originais), como uma
versão anterior deste port fazia. Esse mesmo `no_portador` é reaproveitado tanto no nome do
arquivo quanto nas três linhas (header, detalhe, trailer). `ext` é a extensão original do
arquivo de importação com o `pro_id` do cartório inserido no meio (ex: original `.231` +
cartório `7` vira `.2371`). No modo avulso, `no_portador = "000"` e a extensão usa o ano com 2
dígitos + `pro_id` + `"1"`. Arquivos além do primeiro de uma mesma divisão por quantidade ganham
um sufixo numérico incremental no nome (`2`, `3`, ...).

O header tem um trecho sempre hardcoded — `VERSAO_LAYOUT ("043") + MUNICIPIO_FORCADO
("2304400")`. `"043"` não é um código de portador: é o campo oficial "Versão do Layout" do
padrão Febraban (posição 90-92, ver seção seguinte) — o próprio número da versão do layout
("Layout Único – Versão 4.3"), uma constante da especificação, não algo calculado. Já
`"2304400"` (código IBGE de Fortaleza-CE) é sempre forçado, não vem de
`cad_empresa.scodmunicipio` — comentário do legado: "estou forçando o código do município pq a
CEF não manda essa informação".

## Conformidade com o layout oficial Febraban

O layout de largura fixa (header/detalhe/trailer, 600 bytes/linha) segue o **Layout Único de
Protesto Centralizado v4.3 da Febraban** (`043Febraban.pdf`, 20/04/2010 — mesmo documento que dá
nome ao campo "Versão do Layout" acima). Esse documento também explica o papel de cada arquivo:

- **Arquivo Remessa** (bancos → distribuidor): é o que `RemessaImporter` lê.
- **Arquivo Confirmação** (distribuidor → bancos): relê a remessa original alterando só os
  campos 31/32/33/34/37 (cartório, protocolo, tipo de ocorrência, data do protocolo, data da
  ocorrência) — **é exatamente o que `ExportadorTitulos` gera**, apesar do formulário legado se
  chamar "Exportar Titulos"/"Gera Remessa de Titulos para Protesto".
- **Arquivo Retorno** (bancos → cartórios, fase final de liquidação): não é gerado aqui.

Conferido campo a campo contra a tabela oficial do "Registro de Transação – Arquivo Remessa"
(posições 1-600) e corrigido um desvio real encontrado nessa conferência: o campo 51
("Complemento do Registro", posição 578-596, 19 bytes, reservado — "preencher com brancos") só
tinha 11 bytes preservados/em branco nas três linhas de detalhe (`linha_detalhe`,
`linha_solidario`, `linha_avulso`); os 8 bytes restantes eram sobrescritos com uma repetição da
data de distribuição. O mesmo desvio existe no `.frm` original (`Mid(rsREM!sRegistro, 578, 11)`
seguido da data, com um comentário `'19` do próprio autor indicando que sabia do tamanho
correto) — não foi corrigido lá, e foi corrigido aqui. Um segundo ajuste, para manter as três
linhas consistentes entre si: `linha_avulso` tinha o campo 37 ("Data da Ocorrência", posição
478-485) hardcoded como zeros (`"00000000"`, com a data real comentada no `.frm` original) — as
outras duas linhas já usavam a data de distribuição ali; `linha_avulso` foi alinhada a elas.

Um terceiro ponto, identificado mas **deliberadamente não alterado** (decisão do usuário): o
header sempre grava `"BFO"+"SDT"+"TPR"` nos campos 05/06/07 (remetente/destinatário/tipo de
transação), que é a combinação de um Arquivo **Remessa** novo (banco→distribuidor). Como o que é
gerado é estruturalmente um Arquivo **Confirmação** (distribuidor→banco), o padrão oficial pede
`"SDT"+"BFO"+"CRT"` nesses campos. Mantido como está — o cartório/sistema receptor real já
recebe esse formato há anos e trocar sem confirmar do lado deles poderia quebrar a leitura.

## Envio por e-mail

`ExportacaoMailer#arquivos_gerados` não é chamado automaticamente pelo `create` — é uma ação
separada (`enviar_email`), que só lê o que já está em `tblarquivos` para a data e envia, um
e-mail por cartório de protesto, com os arquivos daquele cartório em anexo (`to:
pro_email`, `cc: scopiaemail` se presente). Igual ao legado, que também separava "Exportar" de
"Enviar Email" em dois botões distintos.

**Configuração SMTP real não faz parte deste código.**
`config/environments/production.rb` já tem um bloco `smtp_settings` comentado, usando
`Rails.application.credentials.dig(:smtp, ...)` — para o envio funcionar de verdade em
produção, alguém precisa preencher essas credenciais (`bin/rails credentials:edit`) e
descomentar o bloco.

## Como foi testado

- `ExportadorTitulos` chamado dentro de uma transaction com `raise ActiveRecord::Rollback`
  (mesmo método usado para testar `RemessaImporter`), contra uma data real com poucos títulos
  (`dat_dist = 2022-11-29`, 10 títulos — 7 avulsos, 3 de um apresentante), nos modos "todos" e
  "avulso". `File.write` foi substituído por uma escrita numa pasta de scratch, pra não
  depender do caminho de depósito real (que é um caminho Windows do sistema legado, inacessível
  a partir do servidor Rails neste ambiente) nem gravar nada fora de controle.
- Conferido campo a campo (script auxiliar que refatia a linha gerada nas posições esperadas):
  header e trailer sempre com exatamente 600 bytes, linha de detalhe também — inclusive depois
  da correção da transliteração de acentos (sem ela, um nome com "SÃO LUIZ" gerava uma linha de
  601 bytes, já que "Ã" ocupa 2 bytes em UTF-8 embora conte como 1 caractere).
  `TblArquivo.count` conferido antes/durante/depois do rollback (sem mudança).
- Testado de fato via HTTP (`create`), com `cad_empresa.spathdeposito` apontado para
  `/mnt/d/Fontes_SIAC_Andre/Projetos Smart/Distribuidor/dados/` — o caminho real do sistema
  legado, acessível a partir daqui via o mapeamento automático do WSL para o drive `D:` do
  Windows (mesma máquina). 5 arquivos gerados de verdade nessa pasta (modo avulso, data com
  poucos títulos), `tblarquivos` conferido. Esse valor ficou assim deliberadamente (não é mais
  o caminho Windows original) pra viabilizar teste real neste ambiente. Não foi testado o envio
  de e-mail de fato (exigiria credenciais SMTP reais).
- Comparado byte a byte contra um arquivo real gerado pelo sistema legado
  (`D0Y52508.2622`, fornecido pelo usuário: 1 título com 8 devedores solidários pro cartório 2,
  apresentante com `scodcompensacao = "0Y5"`) — confirmou o formato geral (600 bytes/linha,
  header/detalhe/trailer) e revelou que o código do portador deve vir de
  `cad_apresenta.scodcompensacao`, não relido de `tblremessas.sregistro` (ver seção "Nome do
  arquivo e cabeçalho/trailer").
