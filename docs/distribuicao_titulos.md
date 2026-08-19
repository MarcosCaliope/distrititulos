# Distribuição de títulos

Porta do formulário legado VB6 `frmDistribuicaoNew.frm`
(`D:\Fontes_SIAC_Andre\Projetos Smart\Distribuidor\fontes\frmDistribuicaoNew.frm`) para a
aplicação Rails. Sorteia cartório e distribuidor para os títulos recebidos numa data que
ainda não foram distribuídos (`dat_dist` nulo) e regrava o `protocolo` de cada um.

## Onde fica

- `app/services/distribuicao_titulos.rb` — processa a distribuição (equivalente ao botão
  "Processar" do formulário legado).
- `app/services/desfazer_distribuicao.rb` — desfaz a distribuição de uma data.
- `app/models/distribuicao.rb` — mapeia `tbldistribuicao`, a grade usada no sorteio.
- `app/controllers/distribuicoes_controller.rb` — `new`/`create` (processar) e `desfazer`
  (GET mostra quantos títulos seriam afetados, DELETE confirma e reverte).
- `app/views/distribuicoes/`
- Rotas: `resources :distribuicoes, only: %i[new create]` + `collection { get/delete :desfazer }`.
- Acesso pela UI: menu "Distribuição de títulos" / aba "Processos" na home.

## O que o formulário legado fazia

O form tinha dois campos de data — recebimento e distribuição (por padrão, o próximo dia
útil após o recebimento, pulando fim de semana e `tblferiados`) — e um botão "Processar"
que:

1. Se `tbldistribuicao` ainda não tiver nenhuma linha para a data de distribuição, monta a
   grade de sorteio: uma linha por combinação distribuidor × cartório × faixa de valor (ver
   abaixo).
2. Para cada título recebido na data informada e ainda sem `cartorio` (`dat_dist` nulo):
   determina a faixa de valor do título (`cad_faixas`, por `climiteinferior`/
   `climitesuperior`), sorteia uma linha livre da grade dentro dessa faixa e usa o cartório/
   distribuidor sorteados para regravar o título.

Duas regras do legado que **foram mantidas deliberadamente**:

- Só participam do sorteio os `cad_distribuidor` com `participa_sorteio = true` — coluna
  adicionada em `cad_distribuidor` especificamente para isso (não existia no legado, que
  tinha essa regra fixa no código como `dis_id < '3'` em `BuscaDistribuidor`/
  `CriaDistribuicao`). Hoje existem 3 distribuidores cadastrados (`1`, `2`, `3`); só `1` e
  `2` têm `participa_sorteio = true` (mesmo resultado da regra fixa do legado), e o `3`
  (CANUTO) fica de fora — mas agora isso é editável no cadastro de Distribuidores
  (`app/views/distribuidores/_form.html.erb`), não fixo no código. Se nenhum distribuidor
  estiver marcado, `DistribuicaoTitulos` recusa o processamento com uma mensagem amigável em
  vez de sortear sobre uma grade vazia.
- Só participam `cad_protesto` com `ativa_sc_titulos = true` (mesma validação amigável se
  nenhum cartório estiver ativo).

Uma parte do form **não foi portada**: o legado também sorteava um cartório em paralelo via
`BuscaCartorio`/`cad_protesto.blivre`, mas o resultado desse sorteio (`strCart`) nunca era
usado para decidir o cartório do título — quem decide é a grade descrita acima. Pelas linhas
comentadas no `.frm`, dá pra ver que essa era a lógica antiga antes de uma refatoração; ficou
como código morto no legado e não tem efeito no resultado, então não foi replicado.

## A grade de sorteio (`tbldistribuicao`)

Uma linha por distribuidor participante × cartório ativo × faixa de valor, para cada data de
distribuição (`dtdistribuicao, icoddistr, icodcartorio, isequencial` — chave composta). Cada
linha tem um flag `blivre` (livre/ocupada) que funciona como round-robin:

- Ao montar a grade de uma nova data, `blivre` é herdado da distribuição anterior mais
  recente para a mesma combinação distribuidor/cartório/faixa (`blivre_herdado` em
  `DistribuicaoTitulos`) — assim o round-robin não reinicia a cada dia.
- Ao sortear para um título, só entram as linhas `blivre = true` daquela faixa; se nenhuma
  estiver livre, todas voltam a ficar livres antes do sorteio (reabastecimento).
- A linha sorteada fica `blivre = false` e tem `iqtdetitulos` incrementado.

## Novo protocolo

O protocolo do título é regravado como `<cartório><distribuidor><protocolo antigo com zeros
à esquerda até 8 dígitos>` — 10 caracteres no total (limite da coluna `cad_titulos.protocolo`).
Exemplo real visto em teste: protocolo `8879834`, sorteado cartório `5` e distribuidor `2`,
gera protocolo `5208879834` (`5` + `2` + `08879834`). `tbldevedorsolidario.protocolo` é
regravado do mesmo jeito para os devedores solidários daquele título, para continuar batendo
com `cad_titulos.protocolo`.

## Desfazer

`DesfazerDistribuicao` reverte todos os títulos com `dat_dist` numa data: remove o prefixo
de 2 caracteres do protocolo, tira os zeros à esquerda que sobraram do preenchimento até 8
dígitos, e limpa `cartorio`/`oficio`/`dat_dist` (e o protocolo correspondente em
`tbldevedorsolidario`). Também decrementa `iqtdetitulos` na linha da grade que tinha
recebido aquele título.

Isso é uma reconstrução aproximada, não um desfazer perfeito: se o protocolo original já
tinha algum zero à esquerda "de verdade" (não vindo do preenchimento), essa distinção se
perde. É a mesma limitação que o formulário legado já tinha — o botão "Excluir
Distribuição" do VB6 (`cmdDesfaz_Click`) nunca ficava visível para os usuários
(`Visible = 0` no `.frm`) e, além disso, cortava os caracteres errados do protocolo
(`Mid(protocolo, 4)`, ou seja 3 caracteres, quando o prefixo é sempre cartório(1) +
distribuidor(1) = 2). A versão desta aplicação corrige esse deslocamento e expõe a ação na
UI, com o mesmo padrão de confirmação em duas etapas usado em
`RemessasController#purge`/`RemessaImportsController#cancel` (GET mostra quantos títulos
seriam afetados, só executa no DELETE se o usuário redigitar a data).
