class ApresentantesController < ApplicationController
  before_action :set_apresentante, only: %i[show edit update destroy]

  def index
    @apresentantes = Apresentante.order(:nome).limit(50)
    if params[:q].present?
      @apresentantes = @apresentantes.where("nome ILIKE :q OR codigo ILIKE :q OR scodcompensacao ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @apresentante = Apresentante.new
  end

  def create
    @apresentante = Apresentante.new(apresentante_params)
    if @apresentante.save
      redirect_to @apresentante, notice: "Apresentante criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @apresentante.update(apresentante_params)
      redirect_to @apresentante, notice: "Apresentante atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @apresentante.destroy
    redirect_to apresentantes_path, notice: "Apresentante removido."
  end

  private

  def set_apresentante
    @apresentante = Apresentante.find(params[:id])
  end

  def apresentante_params
    params.require(:apresentante).permit(
      :codigo, :nome, :endereco, :fone, :contato, :agencia, :tipo, :convenio, :scustaantecipada,
      :scodcompensacao, :bcra, :scnpj, :scep, :scidade, :sestado, :scontato, :sfone,
      :bdistelet, :bisentos, :bcenprot, :bpermitedevedoroutrapraca
    )
  end
end
