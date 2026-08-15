class TitulosController < ApplicationController
  before_action :set_titulo, only: %i[show edit update destroy]

  def index
    @titulos = Titulo.order(:protocolo).limit(50)
    if params[:q].present?
      # cad_titulos has ~5.7M rows and a non-C collation, so LIKE/ILIKE (even
      # prefix-only) can't use any index here and falls back to scanning most
      # of the table. Only exact equality hits the real indexes (~8ms), so
      # search is limited to that instead of a free-text/substring match.
      @titulos = @titulos.where(
        "protocolo = :q OR num_tit = :q OR cpf_cgc = :q", q: params[:q]
      )
    end
  end

  def show
  end

  def new
    @titulo = Titulo.new
  end

  def create
    @titulo = Titulo.new(titulo_params)
    if @titulo.save
      redirect_to @titulo, notice: "Título criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @titulo.update(titulo_params)
      redirect_to @titulo, notice: "Título atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @titulo.destroy
    redirect_to titulos_path, notice: "Título removido."
  end

  private

  def set_titulo
    @titulo = Titulo.find(params[:id])
  end

  def titulo_params
    params.require(:titulo).permit(
      :protocolo, :tipo_doc, :cpf_cgc, :tipo_tit, :num_tit, :dat_venc, :dat_rece, :valor,
      :dat_dist, :cartorio, :cod_apr, :nome_apr, :devedor, :oficio, :status, :cd_banco,
      :cd_agencia, :cedente, :senddevedor, :scepdevedor, :sciddevedor, :sufdevedor,
      :sdocsacador, :sendsacador, :scepsacador, :scidsacador, :sufsacador, :dat_emissao,
      :snomearquivotexto, :stipoocorrencia, :icodirregularidade, :isql, :sefeitofalencia,
      :sacador
    )
  end
end
