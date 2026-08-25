class Apresentante < ApplicationRecord
  self.table_name = "cad_apresenta"
  self.primary_key = "codigo"

  # Mesma constante/regra de RemessaImporter#call e ExportadorTitulos: cad_titulos.cod_apr
  # guarda cad_apresenta.codigo quando a empresa é o próprio município (cad_empresa.scodmunicipio
  # = 2304400/Fortaleza-CE), senão cad_apresenta.scodcompensacao.
  CODMUNICIPIO_EMPRESA_COD_APR_PROPRIO = "2304400"

  validates :codigo, presence: true, length: { maximum: 6 }
  validates :nome, length: { maximum: 30 }
  validates :endereco, length: { maximum: 30 }
  validates :fone, length: { maximum: 20 }
  validates :contato, length: { maximum: 40 }
  validates :agencia, length: { maximum: 20 }
  validates :tipo, length: { maximum: 1 }
  validates :convenio, length: { maximum: 1 }
  validates :scustaantecipada, length: { maximum: 1 }
  validates :scodcompensacao, length: { maximum: 6 }
  validates :scnpj, length: { maximum: 14 }
  validates :scep, length: { maximum: 10 }
  validates :scidade, length: { maximum: 20 }
  validates :sestado, length: { maximum: 2 }
  validates :scontato, length: { maximum: 30 }
  validates :sfone, length: { maximum: 10 }
  validates :sdeposito, length: { maximum: 150 }

  # Resolve o apresentante a partir de cad_titulos.cod_apr, que guarda codigo ou
  # scodcompensacao dependendo de cad_empresa.scodmunicipio (ver CODMUNICIPIO_EMPRESA_COD_APR_PROPRIO).
  def self.resolver_por_cod_apr(cod_apr)
    return nil if cod_apr.blank?

    if Empresa.take&.scodmunicipio == CODMUNICIPIO_EMPRESA_COD_APR_PROPRIO
      find_by(codigo: cod_apr)
    else
      find_by(scodcompensacao: cod_apr)
    end
  end
end
