# Ports the import logic from the legacy VB6 form frmImpTitulos.frm: parses a
# fixed-width (600 columns per line) remessa file sent by an apresentante/banco,
# validates its structure, and writes titulos/devedores/devedor_solidarios/
# remessas from it. Record types: "0" header, "1" titulo, "9" trailer.
#
# Structural problems (counts that don't match, unknown apresentante, wrong
# record order, file already imported) abort the whole import — nothing is
# written. Per-titulo problems (invalid CPF/CNPJ, missing address number,
# inconsistent dates, etc.) don't abort anything; they just mark that titulo
# irregular (tipo_tit = "*", icodirregularidade set), same as the original.
class RemessaImporter
  class ImportError < StandardError; end

  Result = Struct.new(:success, :log, :titulos_count, keyword_init: true) do
    def success?
      success
    end
  end

  CIDADE_EMPRESA = "FORTALEZA"
  CODMUNICIPIO_EMPRESA_COD_APR_PROPRIO = "2304400"
  APRESENTANTE_SEM_REGRA_PRACA = "073"
  ESPECIES_INDICACAO = %w[DMI DRI CBI].freeze

  def initialize(filename:, content:)
    @filename = filename
    @content = content.to_s
    @log = []
    @titulos_count = 0
  end

  def call
    ActiveRecord::Base.transaction do
      linhas = parse_linhas
      validar_estrutura!(linhas)
      importar!(linhas)
    end
    Result.new(success: true, log: @log, titulos_count: @titulos_count)
  rescue ImportError
    Result.new(success: false, log: @log, titulos_count: 0)
  end

  private

  def grava_log(mensagem)
    @log << mensagem
  end

  def falha!(mensagem)
    grava_log(mensagem)
    grava_log("Nenhum título importado")
    raise ImportError, mensagem
  end

  def campo(linha, posicao, tamanho)
    linha[posicao - 1, tamanho].to_s
  end

  def parse_linhas
    @content.gsub("\r\n", "\n").split("\n").reject { |l| l.strip.empty? }
  end

  # --- Estrutura (aborta tudo se falhar) -----------------------------------

  def validar_estrutura!(linhas)
    grava_log("*** Importação Automática de Títulos")
    grava_log("*** Arquivo de Remessa: #{@filename}")
    grava_log("*** Data: #{Date.current}    Hora: #{Time.current.strftime("%H:%M:%S")}")
    grava_log("Verificando consistência do arquivo de remessa")

    falha!("Importação falhou - Arquivo vazio") if linhas.empty?

    linhas.each_with_index do |linha, index|
      if linha.bytes.any? { |b| b > 127 }
        falha!("Importação falhou - Caractere especial detectado na linha #{index + 1}")
      end

      sequencial = campo(linha, 597, 4).to_i
      if sequencial != index + 1
        falha!("Importação falhou - Sequência de linhas incorreta, linha= #{index + 1}")
      end
    end

    header = linhas.first
    falha!("Importação falhou - Registro header esperado") if campo(header, 1, 1) != "0"

    codigo_compensacao = campo(header, 2, 3)
    apresentante = resolver_apresentante(codigo_compensacao)
    unless apresentante
      falha!("Atenção !!! Apresentante/Banco não Cadastrado com o codigo= #{codigo_compensacao}, Verifique")
    end
    @apresentante = apresentante

    empresa = Empresa.take
    falha!("Importação falhou - Empresa não cadastrada. Cadastre a Empresa antes de importar remessas") unless empresa
    @cod_apr = if empresa.scodmunicipio == CODMUNICIPIO_EMPRESA_COD_APR_PROPRIO
      @apresentante.codigo
    else
      @apresentante.scodcompensacao
    end

    if Remessa.exists?(snomearquivotexto: @filename)
      falha!("Este arquivo de remessa já foi importado. Para importá-lo novamente você deve cancelar a importação anterior")
    end

    portador_header = codigo_compensacao
    qtd_titulos_header = campo(header, 72, 4).to_i
    qtd_indicacoes_header = campo(header, 76, 4).to_i
    qtd_originais_header = campo(header, 80, 4).to_i

    qtd_transacao = 0
    qtd_titulos = 0
    qtd_indicacoes = 0
    qtd_originais = 0

    linhas.each_with_index do |linha, index|
      tipo = campo(linha, 1, 1)
      posicao_ultima = index == linhas.size - 1

      if index.zero?
        next
      elsif !posicao_ultima
        if tipo != "1"
          falha!("Importação falhou - Registro de transação esperado")
        end
        if campo(linha, 2, 3) != portador_header
          falha!("Importação falhou - Divergência quanto ao código do portador (transação)")
        end

        qtd_transacao += 1
        principal = campo(linha, 297, 1) == "1"
        if principal
          qtd_titulos += 1
          if ESPECIES_INDICACAO.include?(campo(linha, 214, 3))
            qtd_indicacoes += 1
          else
            qtd_originais += 1
          end
        end
      elsif tipo != "9"
        falha!("Importação falhou - Registro trailler esperado")
      end
    end

    if qtd_titulos != qtd_titulos_header
      falha!("Importação falhou - Divergência na quantidade de títulos")
    end
    if qtd_indicacoes != qtd_indicacoes_header
      falha!("Importação falhou - Divergência na quantidade de indicações")
    end
    if qtd_originais != qtd_originais_header
      falha!("Importação falhou - Divergência na quantidade de originais")
    end

    trailer = linhas.last
    if campo(trailer, 2, 3) != portador_header
      falha!("Importação falhou - Divergência quanto ao código do portador (trailer)")
    end

    soma_seguranca_trailer = campo(trailer, 53, 5).to_i
    soma_seguranca = qtd_transacao + qtd_titulos + qtd_indicacoes + qtd_originais
    if soma_seguranca != soma_seguranca_trailer
      falha!("Importação falhou - Divergência no somatório de segurança da quantidade")
    end

    grava_log("Arquivo de remessa consistente - Pronto para iniciar importação")
  end

  def resolver_apresentante(codigo_compensacao)
    Apresentante.find_by(scodcompensacao: codigo_compensacao)
  end

  # --- Importação de fato ---------------------------------------------------

  def importar!(linhas)
    ultimo_protocolo = nil

    linhas.each_with_index do |linha, index|
      tipo = campo(linha, 1, 1)
      sequencial = campo(linha, 597, 4).to_i

      case tipo
      when "0"
        grava_log("Lendo registro header")
        grava_remessa(linha, sequencial)
      when "1"
        grava_log("Gravando Título - Sequencial: #{sequencial}")
        if campo(linha, 297, 1) == "1"
          ultimo_protocolo, criticas = inserir_titulo(linha, sequencial)
        else
          criticas = inserir_devedor_solidario(linha, sequencial, ultimo_protocolo)
        end
        grava_remessa(linha, sequencial, icodirreg: criticas[:icodirreg], situacao: criticas[:stipoocorrencia], tipo_tit: criticas[:tipo_tit])
      when "9"
        grava_log("Lendo registro Trailler")
        grava_remessa(linha, sequencial)
      end
    end

    grava_log("Importação concluída. Total de títulos: #{@titulos_count}")
  end

  def grava_remessa(linha, sequencial, icodirreg: 0, situacao: nil, tipo_tit: nil)
    Remessa.create!(
      codapr: @apresentante.codigo,
      datarem: Date.current,
      isql: sequencial,
      situacao: situacao,
      icodirreg: icodirreg,
      tipo_tit: tipo_tit&.slice(0, 2),
      snomearquivotexto: @filename,
      sregistro: linha
    )
  end

  def inserir_titulo(linha, sequencial)
    tipo_doc_devedor = tipo_documento(campo(linha, 343, 3))
    doc_devedor = campo(linha, 346, 14).strip

    criticas = avaliar_criticas(linha, tipo_doc_devedor, doc_devedor, principal: true)

    devedor = garantir_devedor(tipo_doc_devedor, doc_devedor, linha)

    protocolo = ActiveRecord::Base.connection.select_value("SELECT nextval('seq_protocolo')").to_s

    Titulo.create!(
      tipo_doc: tipo_doc_devedor,
      cpf_cgc: doc_devedor,
      tipo_tit: criticas[:tipo_tit],
      num_tit: campo(linha, 217, 11).strip,
      dat_venc: criticas[:dt_vencto],
      dat_rece: Date.current,
      valor: campo(linha, 247, 14).to_i / 100.0,
      cod_apr: @cod_apr,
      nome_apr: @apresentante.nome,
      devedor: devedor.nome,
      protocolo: protocolo,
      cedente: campo(linha, 20, 45).strip,
      icodirregularidade: criticas[:icodirreg],
      snomearquivotexto: @filename,
      stipoocorrencia: criticas[:stipoocorrencia],
      isql: sequencial,
      status: " ",
      sefeitofalencia: campo(linha, 566, 1).strip.presence || "Y",
      sdocsacador: campo(linha, 110, 14),
      sendsacador: campo(linha, 124, 45),
      scepsacador: campo(linha, 169, 8),
      scidsacador: campo(linha, 177, 20),
      sufsacador: campo(linha, 197, 2),
      dat_emissao: criticas[:dt_emissao],
      senddevedor: campo(linha, 371, 45),
      scepdevedor: campo(linha, 416, 8),
      sciddevedor: campo(linha, 424, 20),
      sufdevedor: campo(linha, 444, 2)
    )

    @titulos_count += 1
    [ protocolo, criticas ]
  end

  def inserir_devedor_solidario(linha, sequencial, protocolo)
    grava_log("Controle de Devedor Solidário >=2 Sequencial: #{sequencial}")

    tipo_doc_devedor = tipo_documento(campo(linha, 343, 3))
    doc_devedor = campo(linha, 346, 14).strip
    criticas = avaliar_criticas(linha, tipo_doc_devedor, doc_devedor, principal: false)
    garantir_devedor(tipo_doc_devedor, doc_devedor, linha)

    DevedorSolidario.create!(
      tipo_doc: tipo_doc_devedor,
      cpf_cgc: doc_devedor,
      protocolo: protocolo,
      snumtitulo: campo(linha, 217, 11).strip,
      snossonumero: campo(linha, 199, 15),
      especie: criticas[:tipo_tit],
      snomearquivotexto: @filename,
      sregistro: linha,
      isql: sequencial
    )

    if criticas[:tipo_tit] == "*" && protocolo.present?
      Titulo.where(protocolo: protocolo).update_all(
        tipo_tit: criticas[:tipo_tit],
        stipoocorrencia: criticas[:stipoocorrencia],
        icodirregularidade: criticas[:icodirreg]
      )
    end

    criticas
  end

  def tipo_documento(codigo)
    case codigo
    when "001" then "CGC"
    when "002" then "CPF"
    else "CI"
    end
  end

  def garantir_devedor(tipo_doc, cpf_cgc, linha)
    devedor = Devedor.find_by(tipo_doc: tipo_doc, cpf_cgc: cpf_cgc)
    bairro = campo(linha, 488, 20).strip

    if devedor
      devedor.update!(sbairro: bairro) if bairro.present?
      grava_log("Devedor já cadastrado = #{devedor.nome}")
    else
      devedor = Devedor.create!(
        tipo_doc: tipo_doc,
        cpf_cgc: cpf_cgc,
        nome: campo(linha, 298, 45).strip,
        endereco: campo(linha, 371, 35).strip,
        sbairro: bairro,
        obs: "inserido na importacao do titulo",
        cep: campo(linha, 416, 8).strip
      )
      grava_log("Inserindo Devedor = #{devedor.nome}")
    end

    devedor
  end

  # Espécies não cadastradas não marcam o título irregular (diferente das outras críticas):
  # a espécie é criada na hora, com o próximo código numérico disponível.
  def criar_tipo_tit(abrevia)
    proximo_codigo = TipoTit.pluck(:codigo).select { |c| c.match?(/\A\d+\z/) }.map(&:to_i).max.to_i + 1
    grava_log("Natureza \"#{abrevia}\" não cadastrada. Criando nova espécie com código #{proximo_codigo}")
    TipoTit.create!(codigo: proximo_codigo.to_s, abrevia: abrevia)
  end

  # --- Críticas por título (não abortam, só marcam irregular) --------------

  def avaliar_criticas(linha, tipo_doc_devedor, doc_devedor, principal:)
    tipo_tit = ""
    icodirreg = 0
    stipoocorrencia = ""

    marcar = lambda do |codigo, mensagem|
      icodirreg = codigo
      tipo_tit = "*"
      stipoocorrencia = "5"
      grava_log("Atenção !!! #{mensagem}")
    end

    especie_codigo = campo(linha, 214, 3).strip
    tipo_tit_registro = TipoTit.find_by(abrevia: especie_codigo) || criar_tipo_tit(especie_codigo)
    tipo_tit = tipo_tit_registro.codigo

    unless documento_valido?(tipo_doc_devedor, doc_devedor)
      if doc_devedor == "00000000000000"
        marcar.call(50, "Numero do Documento do Devedor Inválido = 00000000000000, Marcado como Irregular")
      else
        marcar.call(7, "Numero do Documento do Devedor Inválido, Marcado como Irregular")
      end
    end

    doc_sacador = campo(linha, 110, 14).strip
    unless documento_sacador_valido?(doc_sacador)
      marcar.call(10, "CPF/CNPJ do Sacador Inválido, Marcado como Irregular")
    end

    if campo(linha, 217, 11).strip.blank?
      marcar.call(16, "Falta Numero do Titulo")
    end

    endereco_devedor = campo(linha, 371, 45)
    if endereco_devedor.strip.blank?
      marcar.call(6, "Endereço do Devedor Insuficiente")
    elsif endereco_devedor.length < 5
      marcar.call(6, "Endereço do Devedor Menor que 5 posições")
    elsif !endereco_devedor.upcase.match?(%r{S/?\??N})
      marcar.call(6, "Endereço do Devedor não contem número")
    end

    dt_emissao = parse_ddmmaaaa(campo(linha, 228, 8))
    if dt_emissao.nil? || dt_emissao < Date.new(1900, 1, 1)
      dt_emissao = Date.new(1900, 1, 1)
      marcar.call(50, "Data de Emissao invalida. Titulo Marcado como Irregular")
    end

    dt_vencto = resolver_vencimento(linha, dt_emissao)
    if dt_vencto.nil?
      marcar.call(1, "Data de vencimento invalida. Titulo Marcado como Irregular")
      dt_vencto = dt_emissao
    elsif dt_vencto > Date.current
      marcar.call(1, "Data de vencimento maior que apresentação. Titulo Marcado como Irregular")
    elsif dt_emissao > dt_vencto
      marcar.call(1, "Data de Emissao maior que vencimento. Titulo Marcado como Irregular")
    end

    nome_devedor = campo(linha, 298, 45).strip
    if nome_devedor == campo(linha, 20, 45).strip
      marcar.call(3, "Nome do Devedor é igual ao Nome do Cedente. Titulo Marcado como Irregular")
    end
    if nome_devedor == campo(linha, 65, 45).strip
      marcar.call(3, "Nome do Devedor é igual ao Nome do Sacador/Vendedor. Titulo Marcado como Irregular")
    end

    if doc_devedor == doc_sacador
      marcar.call(7, "documento do Devedor é igual ao documento do Credor. Titulo Marcado como Irregular")
    end

    if principal
      praca = campo(linha, 275, 20).strip.upcase
      cidade_devedor = campo(linha, 424, 20).strip.upcase
      apresentante_isento = @apresentante.codigo == APRESENTANTE_SEM_REGRA_PRACA

      if praca != CIDADE_EMPRESA && !apresentante_isento
        marcar.call(15, "Praça de Pagamento diferente")
      end
      if cidade_devedor != CIDADE_EMPRESA && !apresentante_isento
        marcar.call(15, "Cidade do Devedor diferente")
      end
      if tipo_doc_devedor == "CPF" && campo(linha, 566, 1) == "F"
        marcar.call(50, "CPF não pode ser Protestado para fins Falimentares. Titulo Marcado como Irregular")
      end
    end

    { tipo_tit: tipo_tit, icodirreg: icodirreg, stipoocorrencia: stipoocorrencia, dt_emissao: dt_emissao, dt_vencto: dt_vencto }
  end

  def documento_valido?(tipo_doc, documento)
    case tipo_doc
    when "CGC" then cnpj_valido?(documento)
    when "CPF" then cpf_valido?(documento)
    else true
    end
  end

  def documento_sacador_valido?(documento)
    if documento.match?(/\A\d+\z/)
      cpf_valido?(documento[-11..]) || cnpj_valido?(documento)
    else
      cnpj_valido?(documento)
    end
  end

  def cpf_valido?(cpf)
    cpf = cpf.to_s.gsub(/\D/, "").rjust(11, "0")
    return false if cpf.length != 11 || cpf.chars.uniq.length == 1

    [ 9, 10 ].each do |tamanho|
      soma = cpf[0, tamanho].chars.each_with_index.sum { |d, i| d.to_i * (tamanho + 1 - i) }
      digito = (soma * 10) % 11
      digito = 0 if digito == 10
      return false if digito != cpf[tamanho].to_i
    end
    true
  end

  def cnpj_valido?(cnpj)
    cnpj = cnpj.to_s.gsub(/\D/, "").rjust(14, "0")
    return false if cnpj.length != 14 || cnpj.chars.uniq.length == 1

    pesos1 = [ 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 ]
    pesos2 = [ 6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 ]

    soma1 = cnpj[0, 12].chars.each_with_index.sum { |d, i| d.to_i * pesos1[i] }
    digito1 = soma1 % 11
    digito1 = digito1 < 2 ? 0 : 11 - digito1
    return false if digito1 != cnpj[12].to_i

    soma2 = cnpj[0, 13].chars.each_with_index.sum { |d, i| d.to_i * pesos2[i] }
    digito2 = soma2 % 11
    digito2 = digito2 < 2 ? 0 : 11 - digito2
    digito2 == cnpj[13].to_i
  end

  def parse_ddmmaaaa(str)
    return nil unless str.match?(/\A\d{8}\z/)

    Date.new(str[4, 4].to_i, str[2, 2].to_i, str[0, 2].to_i)
  rescue ArgumentError, Date::Error
    nil
  end

  def resolver_vencimento(linha, dt_emissao)
    codigo = campo(linha, 236, 8)
    case codigo
    when "99999999" then dt_emissao
    when "99990001" then dt_emissao + 1
    when "99990030" then dt_emissao + 30
    else parse_ddmmaaaa(codigo)
    end
  end
end
