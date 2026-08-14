class Banco < ApplicationRecord
  self.table_name = "cad_bancos"
  self.primary_key = "codigo"

  validates :codigo, presence: true, length: { maximum: 6 }
  validates :banco, length: { maximum: 30 }
  validates :cd2, length: { maximum: 6 }
  validates :deposito, length: { maximum: 50 }
  validates :vcusta, length: { maximum: 10 }
  validates :bc_proce, length: { maximum: 1 }
  validates :email, length: { maximum: 50 }
  validates :to, length: { maximum: 1 }
  validates :ebanco, length: { maximum: 1 }
  validates :codalfa, length: { maximum: 6 }
end
