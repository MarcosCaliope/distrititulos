class Empresa < ApplicationRecord
  self.table_name = "cad_empresa"
  self.primary_key = "emp_id"

  validates :emp_id, presence: true, length: { maximum: 1 }
  validates :snome, length: { maximum: 100 }
  validates :sfantasia, length: { maximum: 30 }
  validates :sendereco, length: { maximum: 50 }
  validates :sbairro, length: { maximum: 30 }
  validates :scidade, length: { maximum: 50 }
  validates :sestado, length: { maximum: 2 }
  validates :scep, length: { maximum: 10 }
  validates :scnpj, length: { maximum: 18 }
  validates :sfone, length: { maximum: 20 }
  validates :semail, length: { maximum: 50 }
  validates :sweb, length: { maximum: 50 }
  validates :snomeresponsavel, length: { maximum: 50 }
  validates :scpfresponsavel, length: { maximum: 14 }
  validates :snomesubstituto, length: { maximum: 50 }
  validates :spathlogo, length: { maximum: 100 }
  validates :stitulo, length: { maximum: 50 }
  validates :spatharquivos, length: { maximum: 100 }
  validates :snolivro, length: { maximum: 5 }
  validates :scodmunicipio, length: { maximum: 7 }
end
