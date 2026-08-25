# Porta o botão "Enviar Email" (cmdEmail_Click) de frmExportaTitulos.frm: envia os arquivos de
# remessa de exportação gerados para um cartório de protesto, anexando cada arquivo referenciado
# em tblarquivos.spatharq. Configuração SMTP real (config.action_mailer.smtp_settings) ainda
# precisa ser ativada em config/environments/production.rb com credenciais reais — ver
# docs/exportacao_titulos.md.
class ExportacaoMailer < ApplicationMailer
  def arquivos_gerados(protesto:, tbl_arquivos:)
    @protesto = protesto
    @tbl_arquivos = tbl_arquivos

    tbl_arquivos.each do |arquivo|
      next unless arquivo.spatharq.present? && File.exist?(arquivo.spatharq)

      attachments[arquivo.spath.presence || File.basename(arquivo.spatharq)] = File.read(arquivo.spatharq)
    end

    to = protesto.pro_email
    cc = protesto.scopiaemail.presence

    mail(to: to, cc: cc, subject: "Arquivos da Distribuição, Ofício #{protesto.pro_id}")
  end
end
