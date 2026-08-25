# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 0) do
  create_schema "distribuidor"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Standalone sequences used as column defaults (not tied to a serial/identity
  # column, so the schema dumper doesn't emit them automatically).
  execute "CREATE SEQUENCE IF NOT EXISTS cax_aprese_id"
  execute "CREATE SEQUENCE IF NOT EXISTS cax_lanc_id"
  execute "CREATE SEQUENCE IF NOT EXISTS teste"
  execute "CREATE SEQUENCE IF NOT EXISTS smt_devedor_id_dev"
  execute "CREATE SEQUENCE IF NOT EXISTS smt_registro_sk"

  create_table "ace_usuario", primary_key: ["usu_id", "taf_id"], force: :cascade do |t|
    t.integer "usu_id", null: false
    t.integer "taf_id", null: false
    t.string "ace_incluir", limit: 1
    t.string "ace_alterar", limit: 1
    t.string "ace_excluir", limit: 1
    t.string "ace_disparar", limit: 1
    t.string "ace_listar", limit: 1
    t.integer "ace_sistemas", null: false
  end

  create_table "cad_apresenta", primary_key: "codigo", id: { type: :string, limit: 6 }, force: :cascade do |t|
    t.string "nome", limit: 30
    t.string "endereco", limit: 30
    t.string "fone", limit: 20
    t.string "contato", limit: 40
    t.string "agencia", limit: 20
    t.string "tipo", limit: 1
    t.string "convenio", limit: 1
    t.string "scustaantecipada", limit: 1
    t.string "sdeposito", limit: 150
    t.index ["codigo"], name: "cad_apresenta_codigo"
    t.index ["nome"], name: "cad_apresenta_nome"
  end

  create_table "cad_bancos", primary_key: "codigo", id: { type: :string, limit: 6 }, force: :cascade do |t|
    t.string "banco", limit: 30
    t.datetime "data", precision: nil
    t.float "seq"
    t.string "cd2", limit: 6
    t.float "sq_titulo"
    t.string "deposito", limit: 50
    t.string "vcusta", limit: 10
    t.string "bc_proce", limit: 1
    t.float "qtd_tit"
    t.string "email", limit: 50
    t.string "to", limit: 1
    t.string "ebanco", limit: 1
    t.string "codalfa", limit: 6
    t.boolean "bngera"
    t.float "iseqconf"
    t.index ["codigo"], name: "cad_bancos_codigo"
  end

  create_table "cad_devedor", primary_key: ["tipo_doc", "cpf_cgc"], force: :cascade do |t|
    t.string "tipo_doc", limit: 3, null: false
    t.string "cpf_cgc", limit: 14, null: false
    t.string "nome", limit: 50
    t.string "endereco", limit: 35
    t.float "qtd_tit"
    t.string "obs", limit: 35
    t.string "numero_ok", limit: 1
    t.string "cep", limit: 10
    t.string "sbairro", limit: 20
    t.index ["nome"], name: "cad_devedor_nome"
  end

  create_table "cad_distribuidor", primary_key: "dis_id", id: { type: :string, limit: 1 }, force: :cascade do |t|
    t.string "dis_cartorio", limit: 40, null: false
    t.boolean "blivre"
    t.boolean "participa_sorteio", default: false
  end

  create_table "cad_empresa", primary_key: "emp_id", id: { type: :string, limit: 1 }, force: :cascade do |t|
    t.string "snome", limit: 100
    t.string "sfantasia", limit: 30
    t.string "sendereco", limit: 50
    t.string "sbairro", limit: 30
    t.string "scidade", limit: 50
    t.string "sestado", limit: 2
    t.string "scep", limit: 10
    t.string "scnpj", limit: 18
    t.string "sfone", limit: 20
    t.string "semail", limit: 50
    t.string "sweb", limit: 50
    t.string "snomeresponsavel", limit: 50
    t.string "scpfresponsavel", limit: 14
    t.string "snomesubstituto", limit: 50
    t.string "spathlogo", limit: 100
    t.integer "inooficio"
    t.string "stitulo", limit: 50
    t.string "spatharquivos", limit: 100
    t.integer "imodeloctd"
    t.string "snolivro", limit: 5
    t.integer "ifolha"
    t.integer "iqtdefolhas"
    t.integer "iqtdetitulosporfolha"
    t.boolean "binseretitulorejeitado"
    t.string "scodmunicipio", limit: 7
    t.boolean "bselodigital"
    t.string "spathdeposito", limit: 150
    t.string "spathdepositodistribuidor", limit: 150
    t.string "spathprocessados", limit: 150
    t.string "spathconfirmados", limit: 150
    t.integer "iquantidadetitporremessa"
    t.string "stipotitpadraodev", limit: 3
    t.string "sapresentanteeventual", limit: 10
  end

  create_table "cad_especies", primary_key: "codigo", id: { type: :string, limit: 3 }, force: :cascade do |t|
    t.string "descricao", limit: 40
    t.string "cd2", limit: 2
    t.index ["codigo"], name: "cad_especies_codigo"
  end

  create_table "cad_eventual", id: false, force: :cascade do |t|
    t.string "tipo_doc", limit: 3, null: false
    t.string "cpf_cgc", limit: 14, null: false
    t.string "num_tit", limit: 15, null: false
    t.string "endereco", limit: 45
    t.string "cpf", limit: 14
    t.string "nome", limit: 45
    t.string "cedente", limit: 45
    t.string "cep", limit: 10
    t.datetime "emissao", precision: nil
    t.index ["tipo_doc", "cpf_cgc", "num_tit"], name: "cad_eventual_eve_chave"
  end

  create_table "cad_faixas", primary_key: "tipo", id: { type: :string, limit: 1 }, force: :cascade do |t|
    t.float "valor"
    t.integer "num_cart", limit: 2
    t.float "qtd_dia"
    t.float "climiteinferior"
    t.float "climitesuperior"
    t.integer "isequencial"
  end

  create_table "cad_protesto", primary_key: "pro_id", id: { type: :string, limit: 1 }, force: :cascade do |t|
    t.string "pro_cartorio", limit: 40, null: false
    t.string "pro_email", limit: 150, null: false
    t.string "pro_oficial", limit: 40
    t.string "pro_fone", limit: 12
    t.string "id_prot_escritura", limit: 4
    t.boolean "ativa_sc_titulos"
    t.string "scopiaemail", limit: 100
    t.boolean "blivre"
    t.index ["id_prot_escritura"], name: "cad_protesto_id2"
  end

  create_table "cad_tipodoc", primary_key: "tipo_doc", id: { type: :string, limit: 3 }, force: :cascade do |t|
    t.string "descricao", limit: 20
    t.index ["tipo_doc"], name: "cad_tipodoc_tipo_doc"
  end

  create_table "cad_tipostit", primary_key: "codigo", id: { type: :string, limit: 2 }, force: :cascade do |t|
    t.string "descricao", limit: 30
    t.string "abrevia", limit: 3
    t.index ["descricao"], name: "descricaox"
  end

  create_table "cad_titulos", primary_key: "protocolo", id: { type: :string, limit: 10 }, force: :cascade do |t|
    t.string "tipo_doc", limit: 3, null: false
    t.string "cpf_cgc", limit: 14, null: false
    t.string "tipo_tit", limit: 2
    t.string "num_tit", limit: 15, null: false
    t.date "dat_venc"
    t.date "dat_rece", null: false
    t.float "valor", null: false
    t.date "dat_dist"
    t.string "cartorio", limit: 1
    t.string "cod_apr", limit: 6
    t.string "nome_apr", limit: 45
    t.string "devedor", limit: 50
    t.string "oficio", limit: 1
    t.string "status", limit: 2
    t.string "cd_banco", limit: 3
    t.string "cd_agencia", limit: 7
    t.string "cedente", limit: 45
    t.string "senddevedor", limit: 45
    t.string "scepdevedor", limit: 8
    t.string "sciddevedor", limit: 20
    t.string "sufdevedor", limit: 2
    t.string "sdocsacador", limit: 14
    t.string "sendsacador", limit: 45
    t.string "scepsacador", limit: 8
    t.string "scidsacador", limit: 20
    t.string "sufsacador", limit: 2
    t.date "dat_emissao"
    t.string "snomearquivotexto", limit: 50
    t.string "stipoocorrencia", limit: 1
    t.integer "icodirregularidade"
    t.integer "isql"
    t.string "sefeitofalencia", limit: 1
    t.index ["cod_apr"], name: "cad_titulos_cod_apr"
    t.index ["cpf_cgc", "dat_rece"], name: "cad_titulos_cpf_cgc_rece2"
    t.index ["dat_dist"], name: "cad_titulos_dat_dist"
    t.index ["dat_rece"], name: "cad_titulos_dat_rece"
    t.index ["devedor"], name: "cad_titulos_devedor"
    t.index ["isql"], name: "cad_titulos_isql"
    t.index ["num_tit", "dat_rece"], name: "cad_titulos_num_tit_rece"
    t.index ["num_tit"], name: "cad_titulos_num_tit"
    t.index ["protocolo"], name: "cad_titulos_protocolo"
    t.index ["sdocsacador"], name: "cad_titulos_sdocsacador"
    t.index ["snomearquivotexto"], name: "cad_titulos_snomearquivotexto"
    t.index ["tipo_doc", "cpf_cgc", "dat_rece"], name: "cad_titulos_cpf_cgc_rece"
    t.index ["tipo_doc", "cpf_cgc", "num_tit"], name: "cad_titulos_cpf_cgc"
  end

  create_table "cad_usuario", primary_key: "usu_id", id: :serial, force: :cascade do |t|
    t.string "usu_nome", limit: 45, null: false
    t.string "usu_login", limit: 10, null: false
    t.string "usu_senha", limit: 10, null: false
    t.string "usu_status", limit: 1
    t.index ["usu_login"], name: "usu_loginx"
  end

  create_table "cax_apresentante", primary_key: "codigo", id: { type: :string, limit: 5, default: -> { "nextval('cax_aprese_id'::regclass)" } }, force: :cascade do |t|
    t.string "apresent", limit: 45
    t.string "fone", limit: 10
    t.float "qtd"
    t.index ["apresent"], name: "cax_apre_ind1"
    t.index ["apresent"], name: "cax_apresentante_apresent"
    t.index ["codigo"], name: "cax_apresentante_codigo"
  end

  create_table "cax_config", id: false, force: :cascade do |t|
    t.float "numero"
    t.string "fonte", limit: 20
    t.integer "tam", limit: 2
    t.float "margem_e"
    t.float "total"
    t.float "sq_apr"
  end

  create_table "cax_lancamentos", primary_key: "numero", id: :float, default: -> { "nextval('cax_lanc_id'::regclass)" }, force: :cascade do |t|
    t.string "cod_apr", limit: 5
    t.datetime "data", precision: nil
    t.string "cod_tipo", limit: 3
    t.float "valor"
    t.float "qtd"
    t.index ["data"], name: "cax_lancamentos_data"
  end

  create_table "cax_tipos", primary_key: "codigo", id: { type: :string, limit: 3 }, force: :cascade do |t|
    t.string "descricao", limit: 30
    t.float "valor"
    t.float "vr_tot"
    t.float "qt_tot"
    t.float "emolumentos"
    t.float "fermoju"
    t.float "iss"
    t.float "ferc"
    t.index ["codigo"], name: "cax_tipos_codigo"
  end

  create_table "cfg_bancos", id: false, force: :cascade do |t|
    t.float "distdor"
    t.string "senha", limit: 10
    t.string "cd_banco", limit: 3
    t.string "bc_proce", limit: 1
    t.float "qtd_tit"
    t.string "onde_gera", limit: 40
    t.float "protocolo"
    t.string "net_dialup", limit: 20
    t.string "net_usua", limit: 30
    t.string "net_senha", limit: 10
    t.string "pop_host", limit: 30
    t.string "pop_usua", limit: 10
    t.string "pop_senha", limit: 10
    t.string "net_caixa", limit: 40
    t.string "smtp_host", limit: 30
  end

  create_table "cfg_contadores", primary_key: "id_co", id: :integer, default: -> { "nextval('teste'::regclass)" }, force: :cascade do |t|
    t.datetime "data_m1", precision: nil
    t.datetime "data_m2", precision: nil
    t.string "usuario", limit: 10
    t.string "senha", limit: 10
    t.string "acesso", limit: 20
    t.float "num_cart"
    t.datetime "datahoje", precision: nil
    t.string "qual_of", limit: 1
    t.string "onde_load", limit: 30
    t.float "num_dist"
    t.float "sq_certn"
    t.float "sq_certp"
    t.float "seqcont1"
    t.float "seqcont2"
    t.float "seqcont3"
    t.float "cf_cont_d1"
    t.float "cf_cont_d2"
    t.float "cf_cont_d3"
    t.float "sq_eve2_d1"
    t.float "sq_eve2_d2"
    t.float "sq_eve2_d3"
    t.float "ps_titulo_digital"
    t.float "ps_titulo_digitado"
    t.float "ps_emolumentos"
    t.float "ps_fermoju"
    t.float "ps_iss"
    t.float "ps_selo"
    t.float "ps_faadep"
  end

  create_table "cfg_menu", primary_key: "cme_id", id: :serial, force: :cascade do |t|
    t.string "descricao", limit: 30, null: false
    t.string "nome_exe", limit: 20, null: false
    t.date "data_atualizar"
  end

  create_table "cfg_sistemas", primary_key: "campo_pk", id: { type: :string, limit: 1 }, force: :cascade do |t|
    t.integer "tes_distribuidor", null: false
    t.integer "ein_distribuidor", null: false
    t.integer "eca_distribuidor", null: false
    t.string "local_server", limit: 100
  end

  create_table "cfg_tarefas", primary_key: "taf_id", id: :serial, force: :cascade do |t|
    t.integer "taf_sistemas", null: false
    t.string "tipos_id2", limit: 2, null: false
    t.string "taf_descricao", limit: 30, null: false
  end

  create_table "cfg_tipos", primary_key: ["tipos_id", "tipos_id2"], force: :cascade do |t|
    t.string "tipos_id", limit: 10, null: false
    t.string "tipos_id2", limit: 2, null: false
    t.string "tipos_descricao", limit: 25, null: false
  end

  create_table "eca_totaldia", id: false, force: :cascade do |t|
    t.datetime "data", precision: nil
    t.float "oficio1"
    t.float "oficio2"
    t.float "oficio3"
    t.index ["data"], name: "eca_totaldia_data"
  end

  create_table "ein_totaldia", id: false, force: :cascade do |t|
    t.datetime "data", precision: nil, null: false
    t.integer "oficio1", null: false
    t.integer "oficio2", null: false
    t.integer "oficio3", null: false
    t.index ["data"], name: "ein_totaldiax"
  end

  create_table "esc_capital", primary_key: "numero", id: :serial, force: :cascade do |t|
    t.datetime "data", precision: nil
    t.string "tipo", limit: 40
    t.string "nm_out", limit: 70
    t.string "ed_out", limit: 50
    t.string "cpf", limit: 15
    t.string "cartorio", limit: 1
    t.string "cidade", limit: 30
    t.index ["data"], name: "esc_capital_data"
  end

  create_table "esc_interior", primary_key: "numero", id: :serial, force: :cascade do |t|
    t.datetime "data", precision: nil
    t.string "tipo", limit: 40
    t.string "nm_out", limit: 70
    t.string "end_out", limit: 50
    t.string "cpf", limit: 15
    t.string "cartorio", limit: 1
    t.string "cidade", limit: 30
    t.index ["data"], name: "escr_te_data"
  end

  create_table "log_monitora", primary_key: "log_data", id: :date, force: :cascade do |t|
    t.boolean "log_liberada", default: false
  end

  create_table "smt_devedor", primary_key: "id_dev", id: :integer, default: -> { "nextval('smt_devedor_id_dev'::regclass)" }, force: :cascade do |t|
    t.string "tipo_doc", limit: 3
    t.string "cnpj_cpf", limit: 14
    t.string "nome", limit: 50
    t.string "email", limit: 200
    t.boolean "ligado", null: false
    t.float "quantidade"
    t.string "ocorrencia", limit: 8
    t.string "from", limit: 70
    t.string "cc", limit: 200
    t.boolean "gc", default: false, null: false
    t.index ["nome"], name: "smt_devedor_nome"
    t.index ["tipo_doc", "cnpj_cpf"], name: "smt_devedor_cnpj_cpf"
  end

  create_table "smt_emails", primary_key: "id_email", id: :serial, force: :cascade do |t|
    t.string "email", limit: 100, null: false
    t.string "tipo", limit: 4, null: false
    t.integer "id_dev", null: false
    t.boolean "ligado"
    t.index ["id_dev"], name: "id_devx2"
  end

  create_table "smt_registro", primary_key: "numero", id: :integer, default: -> { "nextval('smt_registro_sk'::regclass)" }, force: :cascade do |t|
    t.date "dat_rece"
    t.string "tipo_doc", limit: 3
    t.string "cpf_cgc", limit: 14
    t.string "num_tit", limit: 15
    t.string "cedente", limit: 45
    t.string "sacador", limit: 45
    t.string "protocolo", limit: 10
    t.index ["dat_rece", "cpf_cgc"], name: "smt_registro_dat_rece"
    t.index ["tipo_doc", "cpf_cgc", "num_tit"], name: "smt_registro_cpf_cgc"
  end

  create_table "smt_registro2", id: false, force: :cascade do |t|
    t.date "dat_rece"
    t.string "tipo_doc", limit: 3
    t.string "cpf_cgc", limit: 14
    t.string "num_tit", limit: 15
    t.string "cedente", limit: 45
    t.string "sacador", limit: 45
    t.string "protocolo", limit: 10
    t.index ["dat_rece", "cpf_cgc"], name: "smt_registro_dat_rece2"
    t.index ["tipo_doc", "cpf_cgc", "num_tit"], name: "smt_registro_cpf_cgc2"
  end

  create_table "tblarquivos", primary_key: ["pro_id", "dist_id", "data", "cod_apr"], force: :cascade do |t|
    t.string "pro_id", limit: 1, null: false
    t.string "dist_id", limit: 1, null: false
    t.date "data", null: false
    t.string "cod_apr", limit: 6, null: false
    t.string "spatharq", limit: 100
    t.string "spath", limit: 100
  end

  create_table "tblatos", primary_key: ["icodato", "ano"], force: :cascade do |t|
    t.integer "icodato", null: false
    t.string "cemolumento", limit: 10
    t.string "cfermoju", limit: 10
    t.string "cselo", limit: 10
    t.string "ciss", limit: 10
    t.string "cfaadep", limit: 10
    t.string "ano", limit: 4, null: false
    t.string "cfrmp", limit: 10
  end

  create_table "tbldevedorsolidario", primary_key: ["tipo_doc", "cpf_cgc", "protocolo"], force: :cascade do |t|
    t.string "tipo_doc", limit: 3, null: false
    t.string "cpf_cgc", limit: 14, null: false
    t.string "protocolo", limit: 10, null: false
    t.string "snumtitulo", limit: 11
    t.string "snossonumero", limit: 15
    t.string "especie", limit: 3
    t.string "snomearquivotexto", limit: 50
    t.string "sregistro", limit: 650
    t.integer "isql"
  end

  create_table "tbldistribuicao", primary_key: ["dtdistribuicao", "icoddistr", "icodcartorio", "isequencial"], force: :cascade do |t|
    t.date "dtdistribuicao", null: false
    t.integer "icoddistr", null: false
    t.integer "icodcartorio", null: false
    t.integer "isequencial", null: false
    t.float "climiteinferior"
    t.float "climitesuperior"
    t.integer "iqtdetitulos"
    t.boolean "blivre"
  end

  create_table "tblferiados", primary_key: "dtferiado", id: :date, force: :cascade do |t|
    t.string "sdescricao", limit: 50
  end

  create_table "tblremessas", primary_key: ["codapr", "snomearquivotexto", "isql"], force: :cascade do |t|
    t.string "codapr", limit: 6, null: false
    t.date "datarem"
    t.integer "isql", null: false
    t.string "situacao", limit: 2
    t.integer "icodirreg"
    t.string "tipo_tit", limit: 2
    t.string "snomearquivotexto", limit: 50, null: false
    t.string "sregistro", limit: 650
  end

  create_table "tes_movimento", primary_key: "numero", id: :serial, force: :cascade do |t|
    t.datetime "data", precision: nil, null: false
    t.string "testador", limit: 70, null: false
    t.string "cartorio", limit: 1
    t.index ["data"], name: "tes_movimento_data"
  end

  create_table "tes_totaldia", id: false, force: :cascade do |t|
    t.datetime "data", precision: nil
    t.float "oficio1"
    t.float "oficio2"
    t.float "oficio3"
    t.index ["data"], name: "tes_totaldia_data"
  end
end
