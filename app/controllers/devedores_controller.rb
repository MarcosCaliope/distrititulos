class DevedoresController < ApplicationController
  before_action :set_devedor, only: %i[show edit update destroy]

  def index
    @devedores = Devedor.order(:nome).limit(50)
    if params[:q].present?
      @devedores = @devedores.where("nome ILIKE :q OR cpf_cgc ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @devedor = Devedor.new
  end

  def create
    @devedor = Devedor.new(devedor_params)
    if @devedor.save
      redirect_to @devedor, notice: "Devedor criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @devedor.update(devedor_params)
      redirect_to @devedor, notice: "Devedor atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @devedor.destroy
    redirect_to devedores_path, notice: "Devedor removido."
  end

  private

  def set_devedor
    @devedor = Devedor.find(params[:id].split(Devedor.param_delimiter, 2))
  end

  def devedor_params
    params.require(:devedor).permit(
      :tipo_doc, :cpf_cgc, :nome, :endereco, :qtd_tit, :obs, :numero_ok, :cep, :sbairro
    )
  end
end
