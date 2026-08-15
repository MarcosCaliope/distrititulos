class AtosController < ApplicationController
  before_action :set_ato, only: %i[show edit update destroy]

  def index
    @atos = Ato.order(:ano, :icodato).limit(50)
    if params[:q].present?
      @atos = @atos.where("icodato::text ILIKE :q OR ano ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @ato = Ato.new
  end

  def create
    @ato = Ato.new(ato_params)
    if @ato.save
      redirect_to @ato, notice: "Ato criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @ato.update(ato_params)
      redirect_to @ato, notice: "Ato atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @ato.destroy
    redirect_to atos_path, notice: "Ato removido."
  end

  private

  def set_ato
    @ato = Ato.find(params[:id].split(Ato.param_delimiter, 2))
  end

  def ato_params
    params.require(:ato).permit(
      :icodato, :ano, :cemolumento, :cfermoju, :cselo, :ciss, :cfaadep, :cfrmp
    )
  end
end
