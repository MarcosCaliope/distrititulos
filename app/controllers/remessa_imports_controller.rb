class RemessaImportsController < ApplicationController
  def new
  end

  def create
    file = params[:file]
    if file.blank?
      flash.now[:alert] = "Selecione um arquivo de remessa."
      render :new, status: :unprocessable_entity
      return
    end

    @filename = file.original_filename
    @result = RemessaImporter.new(filename: @filename, content: file.read).call
  end

  # Shows how many rows a given remessa filename would remove, before confirming.
  def cancel
    @filename = params[:filename].presence

    if @filename
      @titulos_count = Titulo.where(snomearquivotexto: @filename).count
      @remessas_count = Remessa.where(snomearquivotexto: @filename).count
      @devedor_solidarios_count = DevedorSolidario.where(snomearquivotexto: @filename).count
    end

    return unless request.delete?

    if @filename.blank? || params[:confirm_filename] != @filename
      flash.now[:alert] = "Digite o mesmo nome de arquivo para confirmar."
      render :cancel, status: :unprocessable_entity
      return
    end

    titulos_removidos = Titulo.where(snomearquivotexto: @filename).delete_all
    Remessa.where(snomearquivotexto: @filename).delete_all
    DevedorSolidario.where(snomearquivotexto: @filename).delete_all

    redirect_to new_remessa_import_path, notice: "Importação de \"#{@filename}\" cancelada. #{titulos_removidos} título(s) removido(s)."
  end
end
