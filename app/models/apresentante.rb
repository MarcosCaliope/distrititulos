class Apresentante < ApplicationRecord
  self.table_name = "cad_apresenta"
  self.primary_key = "codigo"

  validates :codigo, presence: true, length: { maximum: 6 }
  validates :nome, length: { maximum: 30 }
  validates :endereco, length: { maximum: 30 }
  validates :fone, length: { maximum: 20 }
  validates :contato, length: { maximum: 40 }
  validates :agencia, length: { maximum: 20 }
  validates :tipo, length: { maximum: 1 }
  validates :convenio, length: { maximum: 1 }
  validates :scustaantecipada, length: { maximum: 1 }
  validates :scodcompensacao, length: { maximum: 6 }
  validates :scnpj, length: { maximum: 14 }
  validates :scep, length: { maximum: 10 }
  validates :scidade, length: { maximum: 20 }
  validates :sestado, length: { maximum: 2 }
  validates :scontato, length: { maximum: 30 }
  validates :sfone, length: { maximum: 10 }
  validates :sdeposito, length: { maximum: 150 }
end
