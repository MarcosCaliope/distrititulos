class RemessasController < ApplicationController
  before_action :set_remessa, only: %i[show edit update destroy]

  def index
    @remessas = Remessa.order(datarem: :desc).limit(50)
    # tblremessas has ~2.45M rows; besides the composite primary key
    # (codapr, snomearquivotexto, isql), codapr/snomearquivotexto/datarem
    # are indexed (the latter two added for this search). Any filter on a
    # column without an index forces a scan that can hang on a
    # rare/non-matching value (same issue found on cad_titulos), so search
    # is limited to these exact-match filters.
    @remessas = @remessas.where(codapr: params[:codapr]) if params[:codapr].present?
    @remessas = @remessas.where(snomearquivotexto: params[:snomearquivotexto]) if params[:snomearquivotexto].present?
    @remessas = @remessas.where(datarem: params[:datarem]) if params[:datarem].present?
  end

  def show
  end

  def new
    @remessa = Remessa.new
  end

  def create
    @remessa = Remessa.new(remessa_params)
    if @remessa.save
      redirect_to @remessa, notice: "Remessa criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @remessa.update(remessa_params)
      redirect_to @remessa, notice: "Remessa atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @remessa.destroy
    redirect_to remessas_path, notice: "Remessa removida."
  end

  private

  def set_remessa
    @remessa = Remessa.find(params[:id].split(Remessa.param_delimiter, 3))
  end

  def remessa_params
    params.require(:remessa).permit(
      :codapr, :datarem, :isql, :situacao, :icodirreg, :tipo_tit, :snomearquivotexto, :sregistro
    )
  end
end
