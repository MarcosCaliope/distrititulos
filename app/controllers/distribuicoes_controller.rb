class DistribuicoesController < ApplicationController
  def new
    @dat_recebimento = params[:dat_recebimento].presence || Date.current.to_s
    @dat_distribuicao = params[:dat_distribuicao].presence || proximo_dia_util(@dat_recebimento).to_s
  end

  def create
    result = DistribuicaoTitulos.new(
      dat_recebimento: params[:dat_recebimento],
      dat_distribuicao: params[:dat_distribuicao]
    ).call

    if result.success?
      redirect_to new_distribuicao_path, notice: "#{result.titulos_distribuidos_count} título(s) distribuído(s) com sucesso."
    else
      @dat_recebimento = params[:dat_recebimento]
      @dat_distribuicao = params[:dat_distribuicao]
      flash.now[:alert] = result.errors.join(" ")
      render :new, status: :unprocessable_entity
    end
  end

  # Mostra quantos títulos seriam afetados por desfazer a distribuição de uma data, antes de confirmar.
  def desfazer
    @dat_distribuicao = params[:dat_distribuicao].presence
    @dat_distribuicao_formatada = Date.parse(@dat_distribuicao).strftime("%d/%m/%Y") if @dat_distribuicao
    @titulos_count = Titulo.where(dat_dist: @dat_distribuicao).count if @dat_distribuicao

    return unless request.delete?

    if @dat_distribuicao.blank? || params[:confirm_data] != @dat_distribuicao_formatada
      flash.now[:alert] = "Digite a mesma data para confirmar."
      render :desfazer, status: :unprocessable_entity
      return
    end

    result = DesfazerDistribuicao.new(dat_distribuicao: @dat_distribuicao).call
    redirect_to new_distribuicao_path, notice: "Distribuição de #{@dat_distribuicao_formatada} desfeita. #{result.titulos_count} título(s) revertido(s)."
  end

  private

  # Próximo dia útil (pula sábado/domingo e tblferiados), igual ao BibDatas.DayAddUtil(data, 1)
  # do formulário legado — só usado para sugerir a data de distribuição no formulário.
  def proximo_dia_util(data)
    dia = Date.parse(data.to_s) + 1.day
    dia += 1.day while dia.saturday? || dia.sunday? || Feriado.exists?(dtferiado: dia)
    dia
  rescue ArgumentError, TypeError
    Date.current
  end
end
