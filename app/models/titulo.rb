class Titulo < ApplicationRecord
  self.table_name = "cad_titulos"
  self.primary_key = "protocolo"

  validates :protocolo, presence: true, length: { maximum: 10 }
  validates :tipo_doc, presence: true, length: { maximum: 3 }
  validates :cpf_cgc, presence: true, length: { maximum: 14 }
  validates :num_tit, presence: true, length: { maximum: 15 }
  validates :dat_rece, presence: true
  validates :valor, presence: true
  validates :tipo_tit, length: { maximum: 2 }
  validates :cartorio, length: { maximum: 1 }
  validates :cod_apr, length: { maximum: 6 }
  validates :nome_apr, length: { maximum: 45 }
  validates :devedor, length: { maximum: 50 }
  validates :oficio, length: { maximum: 1 }
  validates :status, length: { maximum: 2 }
  validates :cd_banco, length: { maximum: 3 }
  validates :cd_agencia, length: { maximum: 7 }
  validates :cedente, length: { maximum: 45 }
  validates :senddevedor, length: { maximum: 45 }
  validates :scepdevedor, length: { maximum: 8 }
  validates :sciddevedor, length: { maximum: 20 }
  validates :sufdevedor, length: { maximum: 2 }
  validates :sdocsacador, length: { maximum: 14 }
  validates :sendsacador, length: { maximum: 45 }
  validates :scepsacador, length: { maximum: 8 }
  validates :scidsacador, length: { maximum: 20 }
  validates :sufsacador, length: { maximum: 2 }
  validates :snomearquivotexto, length: { maximum: 50 }
  validates :stipoocorrencia, length: { maximum: 1 }
  validates :sefeitofalencia, length: { maximum: 1 }
  validates :sacador, length: { maximum: 45 }
end
