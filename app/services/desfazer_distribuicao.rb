# Desfaz a distribuição de todos os títulos com dat_dist numa data: restaura o protocolo
# original (removendo o prefixo cartório+distribuidor de 2 dígitos gravado por
# DistribuicaoTitulos e os zeros à esquerda que sobraram do preenchimento até 8 dígitos) e
# limpa cartorio/oficio/dat_dist. Também decrementa o contador iqtdetitulos da linha da
# grade (tbldistribuicao) que havia recebido esse título.
#
# Restaurar os zeros à esquerda é uma aproximação: se o protocolo original tinha algum zero
# à esquerda "de verdade" (não vindo do padding), essa distinção se perde — mesma limitação
# que o formulário legado já tinha (frmDistribuicaoNew.cmdDesfaz_Click, que fazia
# Mid(protocolo, 4) sem tentar reconstruir o padding).
#
# Diferente do formulário legado (cujo botão "Excluir Distribuição" ficava oculto, nunca
# exposto aos usuários, e cortava os caracteres errados — Mid(protocolo, 4) em vez de 2 —
# já que o prefixo é sempre cartório(1) + distribuidor(1)), esta versão é exposta na UI e
# corrige esse deslocamento.
class DesfazerDistribuicao
  Result = Struct.new(:titulos_count, keyword_init: true)

  def initialize(dat_distribuicao:)
    @dat_distribuicao = dat_distribuicao
  end

  def call
    titulos_count = 0

    ActiveRecord::Base.transaction do
      titulos_afetados.find_each do |titulo|
        desfazer_titulo(titulo)
        titulos_count += 1
      end
    end

    Result.new(titulos_count: titulos_count)
  end

  private

  def titulos_afetados
    Titulo.where(dat_dist: @dat_distribuicao)
  end

  def desfazer_titulo(titulo)
    cartorio = titulo.cartorio
    distribuidor = titulo.oficio
    faixa = Faixa.where("climiteinferior <= :v AND climitesuperior >= :v", v: titulo.valor).first
    protocolo_original = remover_prefixo(titulo.protocolo)

    DevedorSolidario.where(protocolo: titulo.protocolo).update_all(protocolo: protocolo_original)
    titulo.update!(protocolo: protocolo_original, cartorio: nil, oficio: nil, dat_dist: nil)

    return unless faixa && cartorio.present? && distribuidor.present?

    Distribuicao
      .where(dtdistribuicao: @dat_distribuicao, icodcartorio: cartorio.to_i, icoddistr: distribuidor.to_i, isequencial: faixa.isequencial)
      .update_all("iqtdetitulos = GREATEST(iqtdetitulos - 1, 0)")
  end

  def remover_prefixo(protocolo)
    protocolo.to_s[2..].to_s.sub(/\A0+(?=\d)/, "")
  end
end
