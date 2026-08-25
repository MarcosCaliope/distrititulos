class EmpresasController < ApplicationController
  before_action :set_empresa, only: %i[show edit update destroy]

  def index
    @empresas = Empresa.order(:snome).limit(50)
    if params[:q].present?
      @empresas = @empresas.where("snome ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @empresa = Empresa.new
  end

  def create
    @empresa = Empresa.new(empresa_params)
    if @empresa.save
      redirect_to @empresa, notice: "Empresa criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @empresa.update(empresa_params)
      redirect_to @empresa, notice: "Empresa atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @empresa.destroy
    redirect_to empresas_path, notice: "Empresa removida."
  end

  private

  def set_empresa
    @empresa = Empresa.find(params[:id])
  end

  def empresa_params
    permitted = params.require(:empresa).permit(
      :emp_id, :snome, :sfantasia, :sendereco, :sbairro, :scidade, :sestado, :scep, :scnpj,
      :sfone, :semail, :sweb, :snomeresponsavel, :scpfresponsavel, :snomesubstituto,
      :spathlogo, :inooficio, :stitulo, :spatharquivos, :imodeloctd, :snolivro, :ifolha,
      :iqtdefolhas, :iqtdetitulosporfolha, :binseretitulorejeitado, :scodmunicipio,
      :bselodigital, :spathdeposito, :spathdepositodistribuidor, :spathprocessados,
      :spathconfirmados, :iquantidadetitporremessa, :stipotitpadraodev,
      :sapresentanteeventual, :ssmtphost, :ismtpporta, :ssmtpusuario, :ssmtpsenha,
      :ssmtpremetente, :bsmtptls
    )
    # Deixar a senha em branco no formulário não deve apagar a já salva.
    permitted.delete(:ssmtpsenha) if permitted[:ssmtpsenha].blank?
    permitted
  end
end
