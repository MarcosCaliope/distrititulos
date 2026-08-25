# Porta o botão "Enviar Email" (cmdEmail_Click) de frmExportaTitulos.frm: envia os arquivos de
# remessa de exportação gerados para um cartório de protesto, anexando cada arquivo referenciado
# em tblarquivos.spatharq. As credenciais SMTP são lidas de cad_empresa (ver
# docs/exportacao_titulos.md) em vez de config.action_mailer.smtp_settings estático — cada
# empresa/cartório configura o próprio provedor (Gmail, Outlook, etc.) pelo cadastro de
# Empresas, sem precisar mexer em código/credentials.
class ExportacaoMailer < ApplicationMailer
  def arquivos_gerados(protesto:, tbl_arquivos:)
    @protesto = protesto
    @tbl_arquivos = tbl_arquivos
    empresa = Empresa.take

    tbl_arquivos.each do |arquivo|
      next unless arquivo.spatharq.present? && File.exist?(arquivo.spatharq)

      attachments[arquivo.spath.presence || File.basename(arquivo.spatharq)] = File.read(arquivo.spatharq)
    end

    mail_options = {
      to: protesto.pro_email,
      cc: protesto.scopiaemail.presence,
      subject: "Arquivos da Distribuição, Ofício #{protesto.pro_id}",
      delivery_method_options: smtp_settings_de(empresa)
    }
    remetente = empresa&.ssmtpremetente.presence || empresa&.ssmtpusuario.presence
    mail_options[:from] = remetente if remetente

    mail(mail_options)
  end

  private

  def smtp_settings_de(empresa)
    return {} if empresa&.ssmtphost.blank?

    {
      address: empresa.ssmtphost,
      port: empresa.ismtpporta.presence || 587,
      user_name: empresa.ssmtpusuario,
      password: empresa.ssmtpsenha,
      authentication: :plain,
      enable_starttls_auto: empresa.bsmtptls != false
    }
  end
end
