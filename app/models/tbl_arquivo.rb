class TblArquivo < ApplicationRecord
  self.table_name = "tblarquivos"
  self.primary_key = %w[pro_id dist_id data cod_apr]

  validates :pro_id, presence: true, length: { maximum: 1 }
  validates :dist_id, presence: true, length: { maximum: 1 }
  validates :data, presence: true
  validates :cod_apr, presence: true, length: { maximum: 6 }
  validates :spatharq, length: { maximum: 100 }
  validates :spath, length: { maximum: 100 }
end
