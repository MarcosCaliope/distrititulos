class Remessa < ApplicationRecord
  self.table_name = "tblremessas"
  self.primary_key = %w[codapr snomearquivotexto isql]

  validates :codapr, presence: true, length: { maximum: 6 }
  validates :isql, presence: true
  validates :snomearquivotexto, presence: true, length: { maximum: 50 }
  validates :situacao, length: { maximum: 2 }
  validates :tipo_tit, length: { maximum: 2 }
  validates :sregistro, length: { maximum: 650 }
end
