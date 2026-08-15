class TipoDoc < ApplicationRecord
  self.table_name = "cad_tipodoc"
  self.primary_key = "tipo_doc"

  validates :tipo_doc, presence: true, length: { maximum: 3 }
  validates :descricao, length: { maximum: 20 }
end
