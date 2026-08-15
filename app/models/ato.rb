class Ato < ApplicationRecord
  self.table_name = "tblatos"
  self.primary_key = %w[icodato ano]

  validates :icodato, presence: true
  validates :ano, presence: true, length: { maximum: 4 }
  validates :cemolumento, length: { maximum: 10 }
  validates :cfermoju, length: { maximum: 10 }
  validates :cselo, length: { maximum: 10 }
  validates :ciss, length: { maximum: 10 }
  validates :cfaadep, length: { maximum: 10 }
  validates :cfrmp, length: { maximum: 10 }
end
