class TipoTitsController < ApplicationController
  before_action :set_tipo_tit, only: %i[show edit update destroy]

  def index
    @tipo_tits = TipoTit.order(:codigo).limit(50)
    if params[:q].present?
      @tipo_tits = @tipo_tits.where("codigo ILIKE :q OR descricao ILIKE :q OR abrevia ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @tipo_tit = TipoTit.new
  end

  def create
    @tipo_tit = TipoTit.new(tipo_tit_params)
    if @tipo_tit.save
      redirect_to @tipo_tit, notice: "Tipo de título criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tipo_tit.update(tipo_tit_params)
      redirect_to @tipo_tit, notice: "Tipo de título atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tipo_tit.destroy
    redirect_to tipo_tits_path, notice: "Tipo de título removido."
  end

  private

  def set_tipo_tit
    @tipo_tit = TipoTit.find(params[:id])
  end

  def tipo_tit_params
    params.require(:tipo_tit).permit(:codigo, :descricao, :abrevia)
  end
end
