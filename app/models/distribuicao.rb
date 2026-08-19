class Distribuicao < ApplicationRecord
  self.table_name = "tbldistribuicao"
  self.primary_key = %w[dtdistribuicao icoddistr icodcartorio isequencial]

  validates :dtdistribuicao, presence: true
  validates :icoddistr, presence: true
  validates :icodcartorio, presence: true
  validates :isequencial, presence: true
end
