class ProtestosController < ApplicationController
  before_action :set_protesto, only: %i[show edit update destroy]

  def index
    @protestos = Protesto.order(:pro_cartorio).limit(50)
    if params[:q].present?
      @protestos = @protestos.where("pro_cartorio ILIKE :q OR pro_email ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @protesto = Protesto.new
  end

  def create
    @protesto = Protesto.new(protesto_params)
    if @protesto.save
      redirect_to @protesto, notice: "Protesto criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @protesto.update(protesto_params)
      redirect_to @protesto, notice: "Protesto atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @protesto.destroy
    redirect_to protestos_path, notice: "Protesto removido."
  end

  private

  def set_protesto
    @protesto = Protesto.find(params[:id])
  end

  def protesto_params
    params.require(:protesto).permit(
      :pro_id, :pro_cartorio, :pro_email, :pro_oficial, :pro_fone,
      :id_prot_escritura, :ativa_sc_titulos, :scopiaemail, :blivre
    )
  end
end
