class Feriado < ApplicationRecord
  self.table_name = "tblferiados"
  self.primary_key = "dtferiado"

  validates :dtferiado, presence: true
  validates :sdescricao, length: { maximum: 50 }
end
