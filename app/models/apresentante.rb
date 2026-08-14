class Apresentante < ApplicationRecord
  self.table_name = "cad_apresenta"
  self.primary_key = "codigo"

  validates :codigo, presence: true, length: { maximum: 6 }
  validates :nome, length: { maximum: 30 }
  validates :endereco, length: { maximum: 30 }
  validates :fone, length: { maximum: 20 }
  validates :contato, length: { maximum: 40 }
  validates :agencia, length: { maximum: 20 }
  validates :tipo, length: { maximum: 1 }
  validates :convenio, length: { maximum: 1 }
  validates :scustaantecipada, length: { maximum: 1 }
end
