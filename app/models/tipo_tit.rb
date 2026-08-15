class TipoTit < ApplicationRecord
  self.table_name = "cad_tipostit"
  self.primary_key = "codigo"

  validates :codigo, presence: true, length: { maximum: 2 }
  validates :descricao, length: { maximum: 30 }
  validates :abrevia, length: { maximum: 3 }
end
