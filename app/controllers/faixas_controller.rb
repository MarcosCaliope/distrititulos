class FaixasController < ApplicationController
  before_action :set_faixa, only: %i[show edit update destroy]

  def index
    @faixas = Faixa.order(:tipo).limit(50)
    if params[:q].present?
      @faixas = @faixas.where("tipo ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @faixa = Faixa.new
  end

  def create
    @faixa = Faixa.new(faixa_params)
    if @faixa.save
      redirect_to @faixa, notice: "Faixa criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @faixa.update(faixa_params)
      redirect_to @faixa, notice: "Faixa atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @faixa.destroy
    redirect_to faixas_path, notice: "Faixa removida."
  end

  private

  def set_faixa
    @faixa = Faixa.find(params[:id])
  end

  def faixa_params
    params.require(:faixa).permit(
      :tipo, :valor, :num_cart, :qtd_dia, :climiteinferior, :climitesuperior, :isequencial
    )
  end
end
