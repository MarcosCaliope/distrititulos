class Distribuidor < ApplicationRecord
  self.table_name = "cad_distribuidor"
  self.primary_key = "dis_id"

  validates :dis_id, presence: true, length: { maximum: 1 }
  validates :dis_cartorio, presence: true, length: { maximum: 40 }
end
