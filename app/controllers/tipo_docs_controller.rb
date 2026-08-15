class TipoDocsController < ApplicationController
  before_action :set_tipo_doc, only: %i[show edit update destroy]

  def index
    @tipo_docs = TipoDoc.order(:tipo_doc).limit(50)
    if params[:q].present?
      @tipo_docs = @tipo_docs.where("tipo_doc ILIKE :q OR descricao ILIKE :q", q: "%#{params[:q]}%")
    end
  end

  def show
  end

  def new
    @tipo_doc = TipoDoc.new
  end

  def create
    @tipo_doc = TipoDoc.new(tipo_doc_params)
    if @tipo_doc.save
      redirect_to @tipo_doc, notice: "Tipo de documento criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tipo_doc.update(tipo_doc_params)
      redirect_to @tipo_doc, notice: "Tipo de documento atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tipo_doc.destroy
    redirect_to tipo_docs_path, notice: "Tipo de documento removido."
  end

  private

  def set_tipo_doc
    @tipo_doc = TipoDoc.find(params[:id])
  end

  def tipo_doc_params
    params.require(:tipo_doc).permit(:tipo_doc, :descricao)
  end
end
