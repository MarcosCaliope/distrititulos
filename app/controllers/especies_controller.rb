class EspeciesController < ApplicationController
  before_action :set_especie, only: %i[show edit update destroy]

  def index
    @especies = Especie.order(:codigo).limit(50)
    if params[:q].present?
      @especies = @especies.where("codigo ILIKE :q OR descricao ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @especie = Especie.new
  end

  def create
    @especie = Especie.new(especie_params)
    if @especie.save
      redirect_to @especie, notice: "Espécie criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @especie.update(especie_params)
      redirect_to @especie, notice: "Espécie atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @especie.destroy
    redirect_to especies_path, notice: "Espécie removida."
  end

  private

  def set_especie
    @especie = Especie.find(params[:id])
  end

  def especie_params
    params.require(:especie).permit(:codigo, :descricao, :cd2)
  end
end
