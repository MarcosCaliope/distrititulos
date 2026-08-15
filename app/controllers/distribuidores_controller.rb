class DistribuidoresController < ApplicationController
  before_action :set_distribuidor, only: %i[show edit update destroy]

  def index
    @distribuidores = Distribuidor.order(:dis_cartorio).limit(50)
    if params[:q].present?
      @distribuidores = @distribuidores.where("dis_cartorio ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @distribuidor = Distribuidor.new
  end

  def create
    @distribuidor = Distribuidor.new(distribuidor_params)
    if @distribuidor.save
      redirect_to @distribuidor, notice: "Distribuidor criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @distribuidor.update(distribuidor_params)
      redirect_to @distribuidor, notice: "Distribuidor atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @distribuidor.destroy
    redirect_to distribuidores_path, notice: "Distribuidor removido."
  end

  private

  def set_distribuidor
    @distribuidor = Distribuidor.find(params[:id])
  end

  def distribuidor_params
    params.require(:distribuidor).permit(:dis_id, :dis_cartorio, :blivre)
  end
end
