# Devedores solidários a partir do título

Integração entre `Titulo` (`cad_titulos`) e `DevedorSolidario` (`tbldevedorsolidario`),
ligados por `protocolo`: a página do título lista/gerencia os devedores solidários daquele
título, e a listagem de títulos sinaliza quais protocolos têm solidário cadastrado.

## Onde fica

- `app/controllers/titulos_controller.rb#show` — carrega `@devedor_solidarios` com
  `DevedorSolidario.where(protocolo: @titulo.protocolo)`.
- `app/views/titulos/show.html.erb` — card "Devedores solidários": lista cada um (tipo de
  documento, CPF/CNPJ, nome) com ações Ver/Editar/Remover, e um botão "Novo devedor
  solidário".
- `app/controllers/devedor_solidarios_controller.rb#new` — aceita `protocolo`/`snumtitulo`
  via query string para pré-preencher o formulário quando vem do título.
- `app/views/devedor_solidarios/new.html.erb` — o link "Voltar" aponta para o título
  (`titulo_path(params[:protocolo])`) quando `protocolo` está presente na query string, e
  para a listagem de devedores solidários caso contrário.
- `app/controllers/titulos_controller.rb#index` / `app/views/titulos/index.html.erb` — rótulo
  "Dev.Sol." ao lado do protocolo, na listagem de títulos, para os protocolos que têm ao
  menos um devedor solidário.

## Nome do devedor solidário

`DevedorSolidario` não guarda o nome — só `tipo_doc`/`cpf_cgc` (chave do devedor) e
`protocolo`. O nome exibido no card do título vem de um lookup em `Devedor` (`cad_devedor`)
por `tipo_doc`+`cpf_cgc` (chave primária da tabela, então é um lookup indexado/barato); se
não houver `cad_devedor` correspondente, mostra "(devedor não cadastrado)" em vez de
quebrar a página.

## Rótulo "Dev.Sol." na listagem de títulos

`tbldevedorsolidario` tem só um índice, uma chave composta `(tipo_doc, cpf_cgc, protocolo)`
— com `protocolo` na terceira posição, um `WHERE protocolo IN (...)` não consegue usar esse
índice de forma seletiva e cai num sequential scan da tabela inteira (~115 mil linhas,
~1s medido com `EXPLAIN ANALYZE`). Como o rótulo é só um indicador visual e não vale a pena
derrubar a página de títulos por causa dele, `protocolos_com_devedor_solidario` roda essa
consulta com `SET LOCAL statement_timeout = '2s'` numa transação própria (separada da
consulta principal de títulos) e, se estourar o timeout, apenas não mostra nenhum rótulo em
vez de propagar o erro.

Se essa consulta continuar lenta com o crescimento da tabela, a solução correta é criar um
índice em `tbldevedorsolidario(protocolo)` no banco (uma alteração de schema real, não um
dado — coordenar antes de aplicar, já que o Postgres é compartilhado com o sistema legado
VB6 e com a aplicação `distribuidor`; ver `manutencao_dados.md` para o histórico de mudanças
feitas direto no banco).
