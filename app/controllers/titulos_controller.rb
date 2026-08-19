class TitulosController < ApplicationController
  before_action :set_titulo, only: %i[show edit update destroy]

  def index
    @titulos = Titulo.order(dat_dist: :desc).limit(50)

    # cad_titulos has ~5.7M rows and a non-C collation, so LIKE/ILIKE (even
    # prefix-only) can't use any index here and falls back to scanning most
    # of the table. protocolo/num_tit/cpf_cgc/dat_rece/dat_dist are matched
    # by exact equality, which hits real indexes. devedor is the one field
    # that still needs a substring search (names), so it's the one filter
    # that can degrade into a near-full-table scan on a rare/misspelled
    # name — the statement_timeout below turns that into a friendly error
    # instead of an indefinitely hanging request.
    if params[:q].present?
      @titulos = @titulos.where("protocolo = :q OR num_tit = :q", q: params[:q])
    end
    @titulos = @titulos.where(cpf_cgc: params[:cpf_cgc]) if params[:cpf_cgc].present?
    @titulos = @titulos.where(dat_rece: params[:dat_rece]) if params[:dat_rece].present?
    @titulos = @titulos.where(dat_dist: params[:dat_dist]) if params[:dat_dist].present?
    @titulos = @titulos.where("devedor ILIKE :q", q: "%#{params[:devedor]}%") if params[:devedor].present?

    if params[:valor].present?
      valor = params[:valor].to_f
      tolerance = valor.abs * 0.05
      @titulos = @titulos.where(valor: (valor - tolerance)..(valor + tolerance))
    end

    begin
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = '5s'")
        @titulos.load
      end
    rescue ActiveRecord::QueryCanceled
      @titulos = Titulo.none
      flash.now[:alert] = "A busca demorou demais e foi cancelada. Combine o nome do devedor com CPF/CNPJ, protocolo ou uma data para refinar."
    end

    @protocolos_com_devedor_solidario = protocolos_com_devedor_solidario(@titulos.map(&:protocolo))
  end

  def show
    @devedor_solidarios = DevedorSolidario.where(protocolo: @titulo.protocolo)
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

  # tbldevedorsolidario's only index has protocolo as its third column, so a
  # WHERE protocolo IN (...) here forces a sequential scan of the whole table
  # (~115k rows, ~1s). That's just for a "Dev.Sol." badge on the index, so it
  # isn't worth failing the whole page over — give it a short timeout and
  # fall back to showing no badges instead.
  def protocolos_com_devedor_solidario(protocolos)
    return Set.new if protocolos.empty?

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = '2s'")
      DevedorSolidario.where(protocolo: protocolos).distinct.pluck(:protocolo).to_set
    end
  rescue ActiveRecord::QueryCanceled
    Set.new
  end

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
