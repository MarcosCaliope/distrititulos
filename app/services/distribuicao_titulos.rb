# Ports the "Processa Distribuição de Títulos" routine from the legacy VB6 form
# frmDistribuicaoNew.frm: for every título recebido numa data e ainda não distribuído
# (dat_dist nulo), sorteia um cartório/distribuidor e regrava o protocolo do título como
# "<cartório><distribuidor><protocolo antigo, com zeros à esquerda até 8 dígitos>".
#
# O sorteio usa uma grade em tbldistribuicao (uma linha por distribuidor × cartório ativo ×
# faixa de valor, ver #criar_grade_se_necessaria) cujo flag "blivre" funciona como um
# round-robin: dentro da faixa de valor do título, sorteia entre as linhas livres da grade;
# se nenhuma estiver livre, libera todas de novo antes de sortear. O estado "blivre" de uma
# distribuição é herdado da distribuição anterior mais recente para a mesma combinação
# cartório/distribuidor/faixa, para não reiniciar o round-robin a cada dia.
#
# Só participam cad_distribuidor com dis_id < "3" e cad_protesto com ativa_sc_titulos = true
# — mesma regra do formulário legado (BuscaDistribuidor/CriaDistribuicao), preservada
# deliberadamente: o cadastro pode ter mais distribuidores/cartórios do que os habilitados a
# participar do sorteio. Não porta o sorteio paralelo do legado via BuscaCartorio/
# cad_protesto.blivre — no VB6 esse sorteio grava um efeito colateral no banco mas seu
# resultado nunca é usado para decidir o cartório do título (isso vem da grade acima); é
# código morto de uma versão anterior do formulário.
class DistribuicaoTitulos
  Result = Struct.new(:success, :errors, :titulos_distribuidos_count, keyword_init: true) do
    def success?
      success
    end
  end

  DISTRIBUIDORES_PARTICIPANTES = "dis_id < '3'"

  def initialize(dat_recebimento:, dat_distribuicao:)
    @dat_recebimento = parse_data(dat_recebimento)
    @dat_distribuicao = parse_data(dat_distribuicao)
    @titulos_distribuidos_count = 0
  end

  def call
    erros = validar
    return Result.new(success: false, errors: erros, titulos_distribuidos_count: 0) if erros.any?

    ActiveRecord::Base.transaction do
      criar_grade_se_necessaria
      distribuir_titulos
    end

    Result.new(success: true, errors: [], titulos_distribuidos_count: @titulos_distribuidos_count)
  end

  private

  def parse_data(valor)
    valor.present? ? Date.parse(valor.to_s) : nil
  rescue ArgumentError, TypeError
    nil
  end

  def validar
    return [ "Data de recebimento inválida." ] if @dat_recebimento.nil?
    return [ "Data de distribuição inválida." ] if @dat_distribuicao.nil?
    return [ "Data de recebimento maior que a data de distribuição." ] if @dat_recebimento > @dat_distribuicao
    return [ "Não foram recebidos títulos válidos nesta data." ] unless titulos_pendentes.exists?

    []
  end

  def titulos_pendentes
    Titulo.where(dat_rece: @dat_recebimento, dat_dist: nil)
  end

  # Uma linha por distribuidor participante × cartório ativo × faixa de valor, só se ainda
  # não existir nenhuma para @dat_distribuicao (mesma checagem do cmdProcessar_Click legado).
  def criar_grade_se_necessaria
    return if Distribuicao.where(dtdistribuicao: @dat_distribuicao).exists?

    distribuidores = Distribuidor.where(DISTRIBUIDORES_PARTICIPANTES).order(:dis_id)
    cartorios = Protesto.where(ativa_sc_titulos: true)
    faixas = Faixa.all

    distribuidores.each do |distribuidor|
      cartorios.each do |cartorio|
        faixas.each do |faixa|
          Distribuicao.create!(
            dtdistribuicao: @dat_distribuicao,
            icoddistr: distribuidor.dis_id.to_i,
            icodcartorio: cartorio.pro_id.to_i,
            isequencial: faixa.isequencial,
            climiteinferior: faixa.climiteinferior,
            climitesuperior: faixa.climitesuperior,
            iqtdetitulos: 0,
            blivre: blivre_herdado(distribuidor, cartorio, faixa)
          )
        end
      end
    end
  end

  def blivre_herdado(distribuidor, cartorio, faixa)
    Distribuicao
      .where(icoddistr: distribuidor.dis_id, icodcartorio: cartorio.pro_id, isequencial: faixa.isequencial)
      .where("dtdistribuicao < ?", @dat_distribuicao)
      .order(dtdistribuicao: :desc)
      .limit(1)
      .pick(:blivre) || false
  end

  def distribuir_titulos
    titulos_pendentes.order(:protocolo).find_each do |titulo|
      faixa = faixa_do_valor(titulo.valor)
      next unless faixa

      sorteado = sortear_grade(faixa.isequencial)
      redistribuir_titulo(titulo, sorteado)
      @titulos_distribuidos_count += 1
    end
  end

  def faixa_do_valor(valor)
    Faixa.where("climiteinferior <= :v AND climitesuperior >= :v", v: valor).first
  end

  def sortear_grade(isequencial)
    grade = Distribuicao.where(dtdistribuicao: @dat_distribuicao, isequencial: isequencial)
    livres = grade.where(blivre: true).to_a

    if livres.empty?
      grade.update_all(blivre: true)
      livres = grade.to_a
    end

    livres.sample
  end

  def redistribuir_titulo(titulo, sorteado)
    novo_protocolo = "#{sorteado.icodcartorio}#{sorteado.icoddistr}#{protocolo_com_padding(titulo.protocolo)}"

    DevedorSolidario.where(protocolo: titulo.protocolo).update_all(protocolo: novo_protocolo)
    titulo.update!(
      protocolo: novo_protocolo,
      cartorio: sorteado.icodcartorio.to_s,
      oficio: sorteado.icoddistr.to_s,
      dat_dist: @dat_distribuicao
    )
    sorteado.update!(blivre: false, iqtdetitulos: sorteado.iqtdetitulos.to_i + 1)
  end

  def protocolo_com_padding(protocolo)
    protocolo.to_s.gsub(/\D/, "").rjust(8, "0")
  end
end
