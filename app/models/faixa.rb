class Faixa < ApplicationRecord
  self.table_name = "cad_faixas"
  self.primary_key = "tipo"

  validates :tipo, presence: true, length: { maximum: 1 }
end
