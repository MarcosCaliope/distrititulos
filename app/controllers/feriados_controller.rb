class FeriadosController < ApplicationController
  before_action :set_feriado, only: %i[show edit update destroy]

  def index
    @feriados = Feriado.order(:dtferiado).limit(50)
    @feriados = @feriados.where("sdescricao ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    if params[:ano].present? && params[:ano].to_i.positive?
      ano = params[:ano].to_i
      @feriados = @feriados.where(dtferiado: Date.new(ano, 1, 1)..Date.new(ano, 12, 31))
    end
  end

  def show
  end

  def new
    @feriado = Feriado.new
  end

  def create
    @feriado = Feriado.new(feriado_params)
    if @feriado.save
      redirect_to @feriado, notice: "Feriado criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @feriado.update(feriado_params)
      redirect_to @feriado, notice: "Feriado atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @feriado.destroy
    redirect_to feriados_path, notice: "Feriado removido."
  end

  private

  def set_feriado
    @feriado = Feriado.find(params[:id])
  end

  def feriado_params
    params.require(:feriado).permit(:dtferiado, :sdescricao)
  end
end
