class Protesto < ApplicationRecord
  self.table_name = "cad_protesto"
  self.primary_key = "pro_id"

  validates :pro_id, presence: true, length: { maximum: 1 }
  validates :pro_cartorio, presence: true, length: { maximum: 40 }
  validates :pro_email, presence: true, length: { maximum: 150 }
  validates :pro_oficial, length: { maximum: 40 }
  validates :pro_fone, length: { maximum: 12 }
  validates :id_prot_escritura, length: { maximum: 4 }
  validates :scopiaemail, length: { maximum: 100 }
end
