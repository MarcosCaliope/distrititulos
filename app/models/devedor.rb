class Devedor < ApplicationRecord
  self.table_name = "cad_devedor"
  self.primary_key = %w[tipo_doc cpf_cgc]

  validates :tipo_doc, presence: true, length: { maximum: 3 }
  validates :cpf_cgc, presence: true, length: { maximum: 14 }
  validates :nome, length: { maximum: 50 }
  validates :endereco, length: { maximum: 35 }
  validates :obs, length: { maximum: 35 }
  validates :numero_ok, length: { maximum: 1 }
  validates :cep, length: { maximum: 10 }
  validates :sbairro, length: { maximum: 20 }
end
