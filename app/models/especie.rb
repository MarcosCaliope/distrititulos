class Especie < ApplicationRecord
  self.table_name = "cad_especies"
  self.primary_key = "codigo"

  validates :codigo, presence: true, length: { maximum: 3 }
  validates :descricao, length: { maximum: 40 }
  validates :cd2, length: { maximum: 2 }
end
