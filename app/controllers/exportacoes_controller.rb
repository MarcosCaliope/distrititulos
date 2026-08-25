class ExportacoesController < ApplicationController
  def new
    @dat_distribuicao = params[:dat_distribuicao].presence || Date.current.to_s
    @modo = params[:modo].presence || "apresentante"
    @codigo_apresentante = params[:codigo_apresentante]
  end

  def create
    result = ExportadorTitulos.new(
      dat_distribuicao: params[:dat_distribuicao],
      modo: params[:modo],
      codigo_apresentante: params[:codigo_apresentante]
    ).call

    if result.success?
      redirect_to new_exportacao_path(dat_distribuicao: params[:dat_distribuicao]),
        notice: "#{result.arquivos_gerados.count} arquivo(s) de remessa gerado(s) com sucesso."
    else
      @dat_distribuicao = params[:dat_distribuicao]
      @modo = params[:modo]
      @codigo_apresentante = params[:codigo_apresentante]
      flash.now[:alert] = result.errors.join(" ")
      render :new, status: :unprocessable_entity
    end
  end

  # Porta o botão "Enviar Email" (cmdEmail_Click) do formulário legado: para cada cartório de
  # protesto ativo, anexa os arquivos gerados na data (tblarquivos) e envia um e-mail. Não
  # regera os arquivos — só envia o que já está registrado em tblarquivos para a data.
  def enviar_email
    data = params[:dat_distribuicao].presence

    if data.blank?
      redirect_to new_exportacao_path, alert: "Informe a data de distribuição."
      return
    end

    arquivos_por_protesto = TblArquivo.where(data: data).group_by(&:pro_id)

    if arquivos_por_protesto.empty?
      redirect_to new_exportacao_path(dat_distribuicao: data), alert: "Não há arquivos gerados nesta data."
      return
    end

    enviados = 0
    Protesto.where(ativa_sc_titulos: true, pro_id: arquivos_por_protesto.keys).find_each do |protesto|
      ExportacaoMailer.arquivos_gerados(protesto: protesto, tbl_arquivos: arquivos_por_protesto[protesto.pro_id]).deliver_later
      enviados += 1
    end

    redirect_to new_exportacao_path(dat_distribuicao: data), notice: "E-mail enfileirado para #{enviados} cartório(s) de protesto."
  end
end
