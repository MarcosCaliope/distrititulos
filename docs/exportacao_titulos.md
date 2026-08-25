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
  `cad_bancos.cd2`. Esta versão localiza via `cad_apresenta` — mas **não** sempre por
  `scodcompensacao`. `cad_titulos.cod_apr` guarda `cad_apresenta.codigo` **ou**
  `cad_apresenta.scodcompensacao`, dependendo de `cad_empresa.scodmunicipio` — a mesma regra
  condicional de `RemessaImporter#call` (`docs/importacao_remessas.md`), replicada aqui em
  `#resolver_apresentante`. Nesta instalação (empresa em Fortaleza-CE) é sempre `codigo`. Já o
  **código do portador escrito no arquivo** (header/detalhe/trailer, posição 2-4, e também usado
  no nome do arquivo) é sempre `scodcompensacao`, independente de qual campo `cod_apr`
  representa — confirmado byte a byte contra um arquivo real do sistema legado (ver seção
  seguinte). Ou seja: dois campos diferentes do apresentante, para dois propósitos diferentes.
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

O layout de largura fixa (header/detalhe/trailer, 600 bytes/linha) é baseado no **Layout Único
de Protesto Centralizado v4.3 da Febraban** (`043Febraban.pdf`, 20/04/2010 — mesmo documento que
dá nome ao campo "Versão do Layout" acima), mas **o `.frm` original diverge da especificação em
alguns pontos deliberadamente** (não são bugs do legado — são convenções que o cartório/sistema
receptor real já espera há anos). Esse documento também explica o papel de cada arquivo:

- **Arquivo Remessa** (bancos → distribuidor): é o que `RemessaImporter` lê.
- **Arquivo Confirmação** (distribuidor → bancos): relê a remessa original alterando só os
  campos 31/32/33/34/37 (cartório, protocolo, tipo de ocorrência, data do protocolo, data da
  ocorrência) — é estruturalmente próximo do que `ExportadorTitulos` gera, apesar do formulário
  legado se chamar "Exportar Titulos"/"Gera Remessa de Titulos para Protesto".
- **Arquivo Retorno** (bancos → cartórios, fase final de liquidação): não é gerado aqui.

**Validação real**: o usuário forneceu um arquivo gerado de verdade pelo sistema legado em
produção (`D0Y52508.2622` — cartório 2, apresentante código `3079`/`scodcompensacao "0Y5"`, 1
protocolo com 8 devedores solidários). Reproduzindo a mesma data/apresentante/cartório com
`ExportadorTitulos`, **as 11 linhas geradas batem byte a byte com o arquivo real** (script
auxiliar comparando linha a linha). Esse teste guiou três correções reais e **descartou uma
"correção" anterior que na verdade era regressão**:

- **Correção real — código do portador**: vinha sendo relido de `tblremessas.sregistro`
  (posição 2-4 do header/detalhe/trailer originais) em vez de usar
  `cad_apresenta.scodcompensacao` diretamente — ver bullet "Apresentante em vez de banco" acima.
- **Correção real — `snomearquivotexto` com padding inconsistente**: `cad_titulos.snomearquivotexto`
  pode vir preenchido com espaços à direita até 50 caracteres (import legado, que grava o campo
  como leu via `Mid()`, sem `Trim()`), enquanto `tblremessas.snomearquivotexto` é gravado sem
  padding (`RemessaImporter` usa o nome do arquivo direto, já sem espaços). Uma busca
  `Remessa.where(snomearquivotexto: titulo.snomearquivotexto)` sem `.strip` no valor do título
  simplesmente não encontrava nada — nenhuma linha de detalhe era escrita (o título ainda
  contava no header, então o sintoma era "gerou header e trailer mas nenhum título"). Todo uso de
  `titulo.snomearquivotexto` numa busca em `Remessa` agora passa por `.strip` antes.
- **Correção real — formatação de número**: `cfg_contadores.ps_titulo_digital` (usado como
  valor de custas padrão) é uma coluna `float`, e `Float#to_s` em Ruby sempre mostra `"0.0"` em
  vez de `"0"` pra um valor
  inteiro (VB6 não mostra o `.0`). Isso só aparecia na variante alfanumérica do campo custas
  (`campo_string`, texto alinhado à esquerda) — a variante numérica (`campo_numerico`, que só
  extrai dígitos) coincidentemente dava o resultado certo mesmo com o bug, por isso não foi
  percebido antes. Corrigido com um helper que só mostra a parte decimal quando ela existe de
  fato.
- **Regressão descartada**: uma sessão anterior "corrigiu" o campo 51 ("Complemento do
  Registro", posição 578-596, 19 bytes) pra um preenchimento de 19 bytes em branco/original,
  interpretando a instrução oficial "reservado, preencher com brancos" ao pé da letra. O arquivo
  real mostra que isso está errado na prática: a posição 578-596 contém, de fato, 11 bytes em
  branco (ou relidos do original, que já vêm em branco) **seguidos da data de distribuição em 8
  dígitos** (`"           25082026"`) — exatamente o que o `.frm` original já fazia
  (`Mid(sRegistro, 578, 11)` + `Format(txtDtDistribuicao, "ddmmyyyy")`). Revertido para essa
  forma nas três linhas (`linha_detalhe`, `linha_solidario`, `linha_avulso`). Moral: a
  especificação oficial descreve a intenção original do padrão, mas o sistema legado (e o que o
  cartório real espera) já se desviou dela de propósito nesse ponto — sem uma referência real
  pra comparar, a leitura "correta" da especificação levava a um resultado byte a byte errado.

Um ponto **identificado mas deliberadamente não alterado** (decisão do usuário, sem arquivo real
de Confirmação pra comparar): o header sempre grava `"BFO"+"SDT"+"TPR"` nos campos 05/06/07
(remetente/destinatário/tipo de transação), que é a combinação de um Arquivo **Remessa** novo
(banco→distribuidor). Como o que é gerado é estruturalmente mais próximo de um Arquivo
**Confirmação** (distribuidor→banco), o padrão oficial pediria `"SDT"+"BFO"+"CRT"` nesses campos
— mas o arquivo real de exemplo também usa `"BFO"+"SDT"+"TPR"` (ver linha 0 do header
comparado acima), então isso **não é mais uma dúvida em aberto**: é o valor certo, confirmado.

## Envio por e-mail

`ExportacaoMailer#arquivos_gerados` não é chamado automaticamente pelo `create` — é uma ação
separada (`enviar_email`), que só lê o que já está em `tblarquivos` para a data e envia, um
e-mail por cartório de protesto, com os arquivos daquele cartório em anexo (`to:
pro_email`, `cc: scopiaemail` se presente). Igual ao legado, que também separava "Exportar" de
"Enviar Email" em dois botões distintos.

**As credenciais SMTP ficam em `cad_empresa`, não em `config.action_mailer.smtp_settings`.**
Seis campos novos: `ssmtphost`, `ismtpporta`, `ssmtpusuario`, `ssmtpsenha`, `ssmtpremetente`,
`bsmtptls` — configuráveis pelo cadastro de Empresas (`app/views/empresas/_form.html.erb`, com
texto de ajuda para Gmail/Outlook). `ExportacaoMailer` lê `Empresa.take` e monta
`delivery_method_options` dinamicamente por e-mail enviado (`address`, `port`, `user_name`,
`password`, `authentication: :plain`, `enable_starttls_auto`), em vez de usar a config estática
de `config/environments/*.rb` — assim o cartório troca de provedor (ou credencial) pela tela,
sem precisar mexer em código/deploy. Se `ssmtphost` estiver vazio, cai no comportamento padrão
do Rails (sem SMTP configurado — tenta `localhost:25` e falha silenciosamente em dev, já que
`raise_delivery_errors = false`).

`ssmtpsenha` é cifrada em repouso via
[Active Record Encryption](https://guides.rubyonrails.org/active_record_encryption.html)
(`encrypts :ssmtpsenha` em `Empresa`) — dá acesso a uma conta de e-mail real. As chaves
(`primary_key`/`deterministic_key`/`key_derivation_salt`, geradas com
`bin/rails db:encryption:init`) ficam em `Rails.application.credentials.active_record_encryption`,
não no banco. `EmpresasController#empresa_params` remove `ssmtpsenha` dos parâmetros quando vem
em branco, pra deixar o campo em branco no formulário não apagar a senha já salva (mesmo padrão
usado por qualquer campo de senha em formulário Rails) — o campo `show`/`_form` nunca exibe a
senha de volta, só se está "Configurada" ou não.

Gmail exige uma [senha de app](https://myaccount.google.com/apppasswords) (não a senha normal
da conta) desde que desativou "apps menos seguros"; Outlook/Office 365 usa
`smtp.office365.com`, porta 587, TLS — ambos com autenticação normal de usuário/senha (não
OAuth2, que exigiria um fluxo bem mais complexo — fora do escopo aqui).

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
- Comparado byte a byte contra um arquivo real gerado pelo sistema legado em produção
  (`D0Y52508.2622`, fornecido pelo usuário: 1 título com 8 devedores solidários pro cartório 2,
  apresentante código `3079`/`scodcompensacao "0Y5"`, data `25/08/2026`) — reproduzindo a mesma
  data/apresentante/cartório contra o dado real (o título e seus 8 solidários realmente existem
  no banco), **as 11 linhas geradas batem byte a byte com o arquivo real** depois das correções
  descritas em "Conformidade com o layout oficial Febraban" (código do portador via
  `scodcompensacao`, `.strip` no `snomearquivotexto` usado pra buscar em `tblremessas`,
  formatação de `ps_titulo_digital`, e a reversão da "correção" incorreta do campo 51). Script
  auxiliar (`raise ActiveRecord::Rollback` + `File.write` redirecionado, mesmo método de sempre)
  gerou os três arquivos do apresentante `3079` na data (cartórios 2, 7 e 8) e comparou linha a
  linha contra o arquivo de referência.
