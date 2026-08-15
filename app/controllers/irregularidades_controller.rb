class IrregularidadesController < ApplicationController
  before_action :set_irregularidade, only: %i[show edit update destroy]

  def index
    @irregularidades = Irregularidade.order(:codigo).limit(100)
    if params[:q].present?
      @irregularidades = @irregularidades.where("descricao ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @irregularidade = Irregularidade.new
  end

  def create
    @irregularidade = Irregularidade.new(irregularidade_params)
    if @irregularidade.save
      redirect_to @irregularidade, notice: "Irregularidade criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @irregularidade.update(irregularidade_params)
      redirect_to @irregularidade, notice: "Irregularidade atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @irregularidade.destroy
    redirect_to irregularidades_path, notice: "Irregularidade removida."
  end

  private

  def set_irregularidade
    @irregularidade = Irregularidade.find(params[:id])
  end

  def irregularidade_params
    params.require(:irregularidade).permit(:codigo, :descricao)
  end
end
