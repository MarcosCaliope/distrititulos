# Ports the "Exportar" button (cmdImportar_Click) from the legacy VB6 form
# frmExportaTitulos.frm: para uma data de distribuição, gera um arquivo de remessa de
# exportação de largura fixa por cartório de protesto (cad_protesto) x apresentante, grava uma
# linha em tblarquivos por arquivo gerado, e devolve a lista de arquivos gerados. Record types
# (posição 1): "0" header, "1" título (+ um por devedor solidário), "9" trailer.
#
# Mudanças deliberadas em relação ao legado (ver docs/exportacao_titulos.md para detalhes):
# - apresentante/pasta de depósito localizados por cad_apresenta.scodcompensacao (não mais
#   cad_bancos.cd2), mesma mudança já feita na importação (RemessaImporter).
# - tipo_tit excluído é configurável (cad_empresa.stipotitpadraodev, cai em "*" se vazio) em
#   vez do "*" hardcoded do legado — exceto na decisão de imprimir irregularidade em
#   GeraDetalhe/GeraSolidario, que no legado sempre comparava com o literal "*" (preservado).
# - pasta de depósito: cad_empresa.spathdeposito se preenchido, senão cad_apresenta.sdeposito.
# - divide em vários arquivos quando cad_empresa.iquantidadetitporremessa está preenchido (>0),
#   um por fatia de títulos, cada um com seu próprio header/trailer recalculados. Isso
#   substitui a variante legada "Exportar Rem Grande" (cmdExpEspecia_Click, não portada) e o
#   bloco de divisão morto/comentado do formulário original.
# - tblarquivos.dist_id (sempre "0" no legado, que removeu a distinção por distribuidor) é
#   reaproveitado como índice da fatia ("0", "1", "2", ...) para não colidir a chave primária
#   quando um lote gera mais de um arquivo — o passo de e-mail não filtra por dist_id, então
#   isso não muda quais arquivos são anexados.
# - não replica o filtro cad_bancos.bngera do modo "T" (sem equivalente em cad_apresenta hoje).
class ExportadorTitulos
  MODOS = %w[apresentante todos avulso].freeze

  ArquivoGerado = Struct.new(:cod_apr, :pro_id, :caminho, :nome, keyword_init: true)
  Result = Struct.new(:success, :errors, :arquivos_gerados, keyword_init: true) do
    def success?
      success
    end
  end

  ESPECIES_INDICACAO = %w[DMI DRI CBI].freeze
  # Sempre forçado, não vem de cad_empresa.scodmunicipio — comentário do legado: "estou
  # forçando o codigo do municipio pq a CEF não manda essa informação".
  MUNICIPIO_FORCADO = "2304400"
  # Campo "Versão do Layout" do padrão Febraban (posição 90-92 do header) — constante da
  # própria especificação ("043Febraban.pdf", Layout Único v4.3), não um código de portador.
  VERSAO_LAYOUT = "043"

  def initialize(dat_distribuicao:, modo:, codigo_apresentante: nil)
    @dat_distribuicao = parse_data(dat_distribuicao)
    @modo = modo.to_s
    @codigo_apresentante = codigo_apresentante.to_s.strip.upcase.presence
    @arquivos_gerados = []
    @empresa = Empresa.take
    @especies = {}
  end

  def call
    erros = validar
    return Result.new(success: false, errors: erros, arquivos_gerados: []) if erros.any?

    ActiveRecord::Base.transaction do
      codigos_apresentante.each do |cod_apr|
        apresentante = Apresentante.find_by(scodcompensacao: cod_apr)
        pasta = pasta_deposito(apresentante)
        next if pasta.blank?

        Protesto.where(ativa_sc_titulos: true).order(:pro_id).find_each do |protesto|
          titulos = titulos_para(cod_apr, protesto).order(:isql).to_a
          next if titulos.empty?

          gerar_arquivos(cod_apr: cod_apr, protesto: protesto, titulos: titulos, pasta: pasta)
        end
      end
    end

    Result.new(success: true, errors: [], arquivos_gerados: @arquivos_gerados)
  end

  private

  def modo_avulso?
    @modo == "avulso"
  end

  def parse_data(valor)
    valor.present? ? Date.parse(valor.to_s) : nil
  rescue ArgumentError, TypeError
    nil
  end

  def validar
    return [ "Data de distribuição inválida." ] if @dat_distribuicao.nil?
    return [ "Modo inválido." ] unless MODOS.include?(@modo)
    return [ "Informe o código de compensação do apresentante." ] if @modo == "apresentante" && @codigo_apresentante.blank?
    if @modo == "apresentante" && Apresentante.find_by(scodcompensacao: @codigo_apresentante).nil?
      return [ "Apresentante não cadastrado, favor verificar." ]
    end
    return [ "Não existem protestos ativos para distribuição de títulos (cadastro de Protestos)." ] unless Protesto.where(ativa_sc_titulos: true).exists?
    return [ "Não existem títulos para exportar nesta data." ] unless titulos_existem?

    []
  end

  def titulos_existem?
    protestos = Protesto.where(ativa_sc_titulos: true).to_a
    codigos_apresentante.any? do |cod_apr|
      protestos.any? { |protesto| titulos_para(cod_apr, protesto).exists? }
    end
  end

  def tipo_tit_excluido
    @empresa&.stipotitpadraodev.presence || "*"
  end

  def codigos_apresentante
    case @modo
    when "apresentante" then [ @codigo_apresentante ]
    when "avulso" then [ "0" ]
    when "todos"
      Titulo.where(dat_dist: @dat_distribuicao)
        .where.not(status: "G")
        .where.not(tipo_tit: tipo_tit_excluido)
        .where.not(cod_apr: "0")
        .distinct
        .pluck(:cod_apr)
        .compact
    else
      []
    end
  end

  def titulos_para(cod_apr, protesto)
    base = Titulo.where(dat_dist: @dat_distribuicao, cartorio: protesto.pro_id).where.not(tipo_tit: tipo_tit_excluido)
    if modo_avulso?
      base.where(status: "G")
    else
      base.where.not(status: "G").where(cod_apr: cod_apr)
    end
  end

  def pasta_deposito(apresentante)
    @empresa&.spathdeposito.presence || apresentante&.sdeposito.presence
  end

  def gerar_arquivos(cod_apr:, protesto:, titulos:, pasta:)
    tamanho_lote = @empresa&.iquantidadetitporremessa.to_i
    lotes = tamanho_lote.positive? ? titulos.each_slice(tamanho_lote).to_a : [ titulos ]

    lotes.each_with_index do |chunk, indice|
      @sequencial = 1
      contagens = calcular_contagens(chunk)
      no_portador, nome_portador, no_remessa, agencia_centralizadora = dados_portador(cod_apr, chunk.last)
      nome_arquivo = nome_arquivo(chunk: chunk, protesto: protesto, indice: indice)

      linhas = [ linha_header(no_portador: no_portador, nome_portador: nome_portador, no_remessa: no_remessa,
                               agencia_centralizadora: agencia_centralizadora, contagens: contagens) ]

      chunk.each do |titulo|
        if modo_avulso?
          linhas.concat(linhas_avulso(titulo))
        else
          linha = linha_detalhe(titulo, no_portador)
          linhas << linha if linha
          DevedorSolidario.where(protocolo: titulo.protocolo).order(:isql).each do |solidario|
            linha_sol = linha_solidario(titulo, solidario)
            linhas << linha_sol if linha_sol
          end
        end
      end

      @sequencial += 1
      linhas << linha_trailer(cod_apr: cod_apr, no_portador: no_portador, nome_portador: nome_portador, contagens: contagens)

      caminho = File.join(pasta, nome_arquivo)
      File.write(caminho, linhas.join("\n") + "\n")

      registro = TblArquivo.find_or_initialize_by(pro_id: protesto.pro_id, dist_id: indice.to_s, data: @dat_distribuicao, cod_apr: cod_apr)
      registro.spatharq = remove_acentos(caminho)
      registro.spath = nome_arquivo
      registro.save!

      @arquivos_gerados << ArquivoGerado.new(cod_apr: cod_apr, pro_id: protesto.pro_id, caminho: caminho, nome: nome_arquivo)
    end
  end

  def calcular_contagens(chunk)
    qtde_titulos = chunk.size
    qtde_indicacoes = chunk.count { |t| ESPECIES_INDICACAO.include?(especie_abrevia(t.tipo_tit)) }
    qtde_originais = qtde_titulos - qtde_indicacoes
    qtde_solidarios = modo_avulso? ? 0 : DevedorSolidario.where(protocolo: chunk.map(&:protocolo)).count
    qtde_registros = qtde_titulos + qtde_solidarios
    soma_valor = chunk.sum { |t| t.valor.to_f }
    soma_seguranca = qtde_indicacoes + qtde_originais + qtde_titulos + qtde_registros
    [ qtde_titulos, qtde_indicacoes, qtde_originais, qtde_registros, soma_valor, soma_seguranca ]
  end

  def dados_portador(cod_apr, ultimo_titulo)
    if modo_avulso?
      return [ "000", campo_string("EVENTUAL", 40), "000000", "000000" ]
    end

    remessa = Remessa.where(codapr: cod_apr, snomearquivotexto: ultimo_titulo.snomearquivotexto).order(:isql).first
    return [ "000", campo_string("", 40), "000000", "000000" ] unless remessa

    reg = remessa.sregistro.to_s
    [ campo(reg, 2, 3), campo(reg, 5, 40), campo(reg, 62, 6), campo(reg, 84, 6) ]
  end

  def nome_arquivo(chunk:, protesto:, indice:)
    if modo_avulso?
      ext = ".#{@dat_distribuicao.strftime('%y')}#{protesto.pro_id}1"
      reg = "000"
    else
      ultimo = chunk.last
      sufixo = ultimo.snomearquivotexto.to_s.strip[-4, 4].to_s.rjust(4, "0")
      ext = "#{sufixo[0, 3]}#{protesto.pro_id}#{sufixo[3, 1]}"
      remessa = Remessa.where(snomearquivotexto: ultimo.snomearquivotexto).order(:isql).first
      reg = remessa ? campo(remessa.sregistro, 2, 3) : "000"
    end

    base = "D#{reg}#{@dat_distribuicao.strftime('%d%m')}#{ext}"
    indice.positive? ? "#{base}#{indice}" : base
  end

  def linha_header(no_portador:, nome_portador:, no_remessa:, agencia_centralizadora:, contagens:)
    qtde_titulos, qtde_indicacoes, qtde_originais, qtde_registros, = contagens
    linha = +"0"
    linha << no_portador
    linha << nome_portador
    linha << Date.current.strftime("%d%m%Y")
    linha << "BFO" << "SDT" << "TPR"
    linha << campo_string(no_remessa, 6)
    linha << qtde_registros.to_s.rjust(4, "0")
    linha << qtde_titulos.to_s.rjust(4, "0")
    linha << qtde_indicacoes.to_s.rjust(4, "0")
    linha << qtde_originais.to_s.rjust(4, "0")
    linha << campo_string(agencia_centralizadora, 6)
    linha << VERSAO_LAYOUT << MUNICIPIO_FORCADO << (" " * 497)
    linha << "0001"
    linha
  end

  def linha_trailer(cod_apr:, no_portador:, nome_portador:, contagens:)
    _, _, _, _, soma_valor, soma_seguranca = contagens
    linha = +"9"
    linha << (numerico?(no_portador) ? campo_numerico(no_portador, 3) : campo_string(no_portador, 3))
    linha << nome_portador
    linha << Date.current.strftime("%d%m%Y")
    linha << campo_numerico(soma_seguranca, 5)
    linha << campo_moeda(soma_valor, 18)
    linha << (" " * 515)
    linha << (numerico?(cod_apr) ? campo_numerico(cod_apr, 6) : campo_string("000#{cod_apr}", 6))
    linha << campo_numerico(@sequencial, 4)
    linha
  end

  # Título não-avulso: relê a linha original importada (tblremessas.sregistro, pela chave
  # codapr+snomearquivotexto+isql do próprio título) e reaproveita a maior parte dos campos por
  # posição — só recalcula cartório/protocolo/tipo-ocorrência/data-ocorrência/irregularidade/
  # sequencial. Se a linha original não existir mais, não escreve nada (igual ao legado — o
  # título ainda entra nas contagens do header, mesmo sem linha de detalhe no corpo).
  def linha_detalhe(titulo, no_portador)
    remessa = Remessa.where(codapr: titulo.cod_apr, snomearquivotexto: titulo.snomearquivotexto, isql: titulo.isql).first
    return nil unless remessa

    reg = remessa.sregistro.to_s
    @sequencial += 1
    @sc_cartorio = campo_numerico(titulo.cartorio, 2)
    @s_no_protocolo = campo_numerico(titulo.protocolo, 10)
    @s_tip_ocorr = campo_string(titulo.stipoocorrencia, 1)
    @s_irreg = titulo.tipo_tit == "*" ? campo_numerico(titulo.icodirregularidade, 2) : "  "
    custas = custas_padrao

    linha = +"1"
    linha << no_portador
    linha << campo(reg, 5, 15)
    linha << troca_arroba_apostrofo(campo(reg, 20, 45))
    linha << campo(reg, 65, 45)
    linha << campo(reg, 110, 14)
    linha << campo(reg, 124, 45)
    linha << campo(reg, 169, 8)
    linha << campo(reg, 177, 20)
    linha << campo(reg, 197, 2)
    linha << campo(reg, 199, 15)
    linha << campo(reg, 214, 3)
    linha << campo(reg, 217, 11)
    linha << campo(reg, 228, 8)
    linha << campo(reg, 236, 8)
    linha << campo(reg, 244, 3)
    linha << campo(reg, 247, 14)
    linha << campo(reg, 261, 14)
    linha << campo(reg, 275, 20)
    linha << campo(reg, 295, 1)
    linha << campo(reg, 296, 1)
    linha << campo(reg, 297, 1)
    linha << campo(reg, 298, 45)
    linha << campo(reg, 343, 3)
    linha << campo(reg, 346, 14)
    linha << campo(reg, 360, 11)
    linha << campo(reg, 371, 45)
    linha << campo(reg, 416, 8)
    linha << campo(reg, 424, 20)
    linha << campo(reg, 444, 2)
    linha << @sc_cartorio
    linha << @s_no_protocolo
    linha << @s_tip_ocorr
    linha << titulo.dat_rece.strftime("%d%m%Y")
    linha << campo_numerico(custas, 10)
    linha << campo(reg, 477, 1)
    linha << @dat_distribuicao.strftime("%d%m%Y")
    linha << @s_irreg
    linha << campo(reg, 488, 20)
    linha << campo_string(custas, 10)
    linha << campo(reg, 518, 6)
    linha << campo(reg, 524, 10)
    linha << campo(reg, 534, 5)
    linha << campo(reg, 539, 15)
    linha << campo(reg, 554, 3)
    linha << campo(reg, 557, 1)
    linha << campo(reg, 558, 8)
    linha << campo(reg, 566, 1)
    linha << campo(reg, 567, 1)
    linha << campo(reg, 568, 10)
    linha << campo(reg, 578, 19)
    linha << (@sequencial >= 10_000 ? campo_numerico(@sequencial, 5) : campo_numerico(@sequencial, 4))
    linha
  end

  # Devedor solidário de um título não-avulso: relê a linha original do próprio solidário em
  # tblremessas (mesma mecânica de #linha_detalhe, mas pela chave isql do solidário) e
  # reaproveita cartório/protocolo/tipo-ocorrência/irregularidade já calculados por
  # #linha_detalhe para o título titular (@sc_cartorio/@s_no_protocolo/@s_tip_ocorr/@s_irreg).
  def linha_solidario(titulo, solidario)
    remessa = Remessa.where(codapr: titulo.cod_apr, snomearquivotexto: titulo.snomearquivotexto, isql: solidario.isql).first
    return nil unless remessa

    reg = remessa.sregistro.to_s
    @sequencial += 1
    custas = custas_padrao

    linha = +""
    linha << campo(reg, 1, 4)
    linha << campo(reg, 5, 15)
    linha << campo(reg, 20, 45)
    linha << campo(reg, 65, 45)
    linha << campo(reg, 110, 14)
    linha << campo(reg, 124, 45)
    linha << campo(reg, 169, 8)
    linha << campo(reg, 177, 20)
    linha << campo(reg, 197, 2)
    linha << campo(reg, 199, 15)
    linha << campo(reg, 214, 3)
    linha << campo(reg, 217, 11)
    linha << campo(reg, 228, 8)
    linha << campo(reg, 236, 8)
    linha << campo(reg, 244, 3)
    linha << campo(reg, 247, 14)
    linha << campo(reg, 261, 14)
    linha << campo(reg, 275, 20)
    linha << campo(reg, 295, 1)
    linha << campo(reg, 296, 1)
    linha << campo(reg, 297, 1)
    linha << campo(reg, 298, 45)
    linha << campo(reg, 343, 3)
    linha << campo(reg, 346, 14)
    linha << campo(reg, 360, 11)
    linha << campo(reg, 371, 45)
    linha << campo(reg, 416, 8)
    linha << campo(reg, 424, 20)
    linha << campo(reg, 444, 2)
    linha << @sc_cartorio.to_s
    linha << @s_no_protocolo.to_s
    linha << @s_tip_ocorr.to_s
    linha << titulo.dat_rece.strftime("%d%m%Y")
    linha << campo_numerico(custas, 10)
    linha << campo(reg, 477, 1)
    linha << @dat_distribuicao.strftime("%d%m%Y")
    linha << @s_irreg.to_s
    linha << campo(reg, 488, 20)
    linha << campo_string(custas, 10)
    linha << campo(reg, 518, 6)
    linha << campo(reg, 524, 10)
    linha << campo(reg, 534, 5)
    linha << campo(reg, 539, 15)
    linha << campo(reg, 554, 3)
    linha << campo(reg, 557, 1)
    linha << campo(reg, 558, 8)
    linha << campo(reg, 566, 1)
    linha << campo(reg, 567, 1)
    linha << campo(reg, 568, 10)
    linha << (" " * 19)
    linha << campo_numerico(@sequencial, 4)
    linha
  end

  # Título avulso/digitado (status "G", sem remessa original importada): monta os campos direto
  # de cad_titulos/cad_devedor, e uma linha igual a esta por devedor solidário (mesmo devedor
  # "pessoa" trocado pelo do solidário). Simplificação deliberada em relação ao legado: quando
  # cad_devedor não é encontrado, o legado pula um conjunto de campos diferente para a linha
  # titular (só endereço/CEP/cidade/UF) e para a linha solidária (nome/doc/RG também) — aqui as
  # duas seguem a mesma regra (só endereço/CEP/cidade/UF ficam de fora).
  def linhas_avulso(titulo)
    linhas = [ linha_avulso(titulo: titulo, tipo_doc: titulo.tipo_doc, cpf_cgc: titulo.cpf_cgc, nome_devedor: titulo.devedor, cont_dev: 1) ]

    cont = 1
    DevedorSolidario.where(protocolo: titulo.protocolo).order(:isql).each do |solidario|
      cont += 1
      devedor_sol = Devedor.find_by(tipo_doc: solidario.tipo_doc, cpf_cgc: solidario.cpf_cgc)
      linhas << linha_avulso(titulo: titulo, tipo_doc: solidario.tipo_doc, cpf_cgc: solidario.cpf_cgc, nome_devedor: devedor_sol&.nome, cont_dev: cont)
    end

    linhas
  end

  def linha_avulso(titulo:, tipo_doc:, cpf_cgc:, nome_devedor:, cont_dev:)
    @sequencial += 1
    especie = especie_abrevia(titulo.tipo_tit)
    emissao = titulo.dat_emissao || titulo.dat_venc
    custas = custas_padrao
    devedor = Devedor.find_by(tipo_doc: tipo_doc, cpf_cgc: cpf_cgc)
    bairro_dev = devedor&.sbairro.presence || (" " * 20)

    linha = +"1000"
    linha << "123456789012345"
    linha << campo_string(texto(titulo.cedente), 45)
    linha << campo_string(texto(titulo.cedente), 45) # cad_titulos não tem coluna "sacador" — legado sempre caía no fallback pro cedente aqui
    linha << campo_numerico(titulo.sdocsacador.presence || "0", 14)
    linha << campo_string(texto(titulo.sendsacador) || " ", 45)
    linha << campo_numerico(limpa_numero(titulo.scepsacador.presence || "60000000"), 8)
    linha << campo_string(texto(titulo.scidsacador) || " ", 20)
    linha << campo_string(titulo.sufsacador || " ", 2)
    linha << "000001111122223"
    linha << campo_string(especie, 3)
    linha << campo_string(titulo.num_tit.to_s[0, 11], 11)
    linha << (emissao ? emissao.strftime("%d%m%Y") : " " * 8)
    linha << (titulo.dat_venc ? titulo.dat_venc.strftime("%d%m%Y") : " " * 8)
    linha << "001"
    linha << campo_moeda(titulo.valor, 14)
    linha << campo_moeda(titulo.valor, 14)
    linha << campo_string("FORTALEZA", 20)
    linha << " "
    linha << "N"
    linha << cont_dev.to_s
    linha << campo_string(texto(nome_devedor.to_s[0, 45]), 45)
    linha << (tipo_doc == "CGC" ? "001" : "002")
    linha << campo_numerico(cpf_cgc, 14)
    linha << ("0" * 11)
    if devedor
      linha << campo_string(texto(devedor.endereco.to_s.gsub(",", ".")), 45)
      linha << campo_numerico(devedor.cep.presence || "60000000", 8)
      linha << campo_string("FORTALEZA", 20)
      linha << "CE"
    end
    linha << campo_numerico(titulo.cartorio, 2)
    linha << campo_numerico(titulo.protocolo, 10)
    linha << " "
    linha << titulo.dat_rece.strftime("%d%m%Y")
    linha << campo_numerico(custas, 10)
    linha << " "
    linha << @dat_distribuicao.strftime("%d%m%Y")
    linha << "  "
    linha << campo_string(texto(bairro_dev), 20)
    linha << (" " * 58)
    linha << (titulo.sefeitofalencia == "Y" || titulo.sefeitofalencia.blank? ? " " : campo_string(titulo.sefeitofalencia, 1))
    linha << (" " * 30)
    linha << campo_numerico(@sequencial, 4)
    linha
  end

  def custas_padrao
    @custas_padrao ||= CfgContador.find_by(id_co: 2)&.ps_titulo_digital.to_s.presence || "0"
  end

  def especie_abrevia(codigo)
    @especies[codigo] ||= TipoTit.find_by(codigo: codigo)&.abrevia.to_s.strip
  end

  # Leitor 1-based de posição fixa, mesma convenção de RemessaImporter#campo — aqui usado para
  # ESCREVER (relê um trecho de tblremessas.sregistro), por isso preenche com espaços à direita
  # se a linha original for mais curta do que o esperado.
  def campo(registro, posicao, tamanho)
    registro.to_s[posicao - 1, tamanho].to_s.ljust(tamanho)
  end

  # Porta de TrataString: alinha à esquerda e completa com espaços até `tamanho`.
  def campo_string(valor, tamanho)
    valor.to_s.strip.ljust(tamanho)[0, tamanho]
  end

  # Porta de TrataDuplo: extrai só os dígitos e completa com zeros à esquerda até `tamanho`.
  def campo_numerico(valor, tamanho)
    valor.to_s.gsub(/\D/, "").rjust(tamanho, "0")
  end

  # Porta de TrataMoeda: valor em centavos, dígitos só, zeros à esquerda até `tamanho`.
  def campo_moeda(valor, tamanho)
    ((valor.to_f * 100).round).to_s.gsub(/\D/, "").rjust(tamanho, "0")
  end

  def limpa_numero(valor)
    valor.to_s.gsub(/\D/, "")
  end

  # Transliteração pra ASCII, só usada em campos digitados direto no cadastro (não nas linhas
  # relidas de tblremessas.sregistro): sem isso, um acento vira um caractere multibyte em UTF-8
  # e o comprimento em BYTES da linha deixa de bater 600, mesmo com 600 caracteres.
  def texto(valor)
    return valor if valor.nil?

    I18n.transliterate(valor.to_s)
  end

  def troca_arroba_apostrofo(valor)
    valor.to_s.upcase.gsub("@", "'")
  end

  def numerico?(valor)
    valor.to_s.strip.match?(/\A\d+\z/)
  end

  def remove_acentos(valor)
    I18n.transliterate(valor.to_s)
  end
end
