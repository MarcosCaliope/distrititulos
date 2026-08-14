class BancosController < ApplicationController
  before_action :set_banco, only: %i[show edit update destroy]

  def index
    @bancos = Banco.order(:banco).limit(50)
    if params[:q].present?
      @bancos = @bancos.where("banco ILIKE :q OR codigo ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @banco = Banco.new
  end

  def create
    @banco = Banco.new(banco_params)
    if @banco.save
      redirect_to @banco, notice: "Banco criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @banco.update(banco_params)
      redirect_to @banco, notice: "Banco atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @banco.destroy
    redirect_to bancos_path, notice: "Banco removido."
  end

  private

  def set_banco
    @banco = Banco.find(params[:id])
  end

  def banco_params
    params.require(:banco).permit(
      :banco, :data, :seq, :codigo, :cd2, :sq_titulo, :deposito, :vcusta,
      :bc_proce, :qtd_tit, :email, :to, :ebanco, :codalfa, :bngera, :iseqconf
    )
  end
end
