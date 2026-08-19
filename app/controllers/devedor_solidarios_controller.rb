class DevedorSolidariosController < ApplicationController
  before_action :set_devedor_solidario, only: %i[show edit update destroy]

  def index
    @devedor_solidarios = DevedorSolidario.order(:protocolo).limit(50)
    if params[:q].present?
      @devedor_solidarios = @devedor_solidarios.where("cpf_cgc ILIKE :q OR protocolo ILIKE :q OR snumtitulo ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @devedor_solidario = DevedorSolidario.new(protocolo: params[:protocolo], snumtitulo: params[:snumtitulo])
  end

  def create
    @devedor_solidario = DevedorSolidario.new(devedor_solidario_params)
    if @devedor_solidario.save
      redirect_to @devedor_solidario, notice: "Devedor solidário criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @devedor_solidario.update(devedor_solidario_params)
      redirect_to @devedor_solidario, notice: "Devedor solidário atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @devedor_solidario.destroy
    redirect_to devedor_solidarios_path, notice: "Devedor solidário removido."
  end

  private

  def set_devedor_solidario
    @devedor_solidario = DevedorSolidario.find(params[:id].split(DevedorSolidario.param_delimiter, 3))
  end

  def devedor_solidario_params
    params.require(:devedor_solidario).permit(
      :tipo_doc, :cpf_cgc, :protocolo, :snumtitulo, :snossonumero, :especie, :snomearquivotexto, :sregistro, :isql
    )
  end
end
