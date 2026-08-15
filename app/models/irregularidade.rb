class Irregularidade < ApplicationRecord
  self.table_name = "irregularidades"
  self.primary_key = "codigo"

  validates :codigo, presence: true
  validates :descricao, presence: true, length: { maximum: 100 }
end
