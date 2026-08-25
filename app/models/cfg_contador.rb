# Tabela de configuração de contadores/valores padrão do sistema legado — não gerenciada por
# nenhum CRUD deste app, só lida (ver ExportadorTitulos, que lê ps_titulo_digital do id_co 2).
class CfgContador < ApplicationRecord
  self.table_name = "cfg_contadores"
  self.primary_key = "id_co"
end
