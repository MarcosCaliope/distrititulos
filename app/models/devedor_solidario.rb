class DevedorSolidario < ApplicationRecord
  self.table_name = "tbldevedorsolidario"
  self.primary_key = %w[tipo_doc cpf_cgc protocolo]

  validates :tipo_doc, presence: true, length: { maximum: 3 }
  validates :cpf_cgc, presence: true, length: { maximum: 14 }
  validates :protocolo, presence: true, length: { maximum: 10 }
  validates :snumtitulo, length: { maximum: 11 }
  validates :snossonumero, length: { maximum: 15 }
  validates :especie, length: { maximum: 3 }
  validates :snomearquivotexto, length: { maximum: 50 }
  validates :sregistro, length: { maximum: 650 }
end
