# Runs RemessaImporter in the background so RemessaImportsController#create can
# redirect immediately to a page that shows live progress (see
# RemessaImportProgress) instead of blocking the request until the whole file
# is processed.
class RemessaImportJob < ApplicationJob
  queue_as :default

  def perform(id, filename, content)
    progress = RemessaImportProgress.new(id)
    progress.start(filename)

    on_progress = ->(log:, processed:, total:) { progress.log(log, processed: processed, total: total) }
    result = RemessaImporter.new(filename: filename, content: content, on_progress: on_progress).call

    progress.finish(result)
  rescue StandardError => e
    progress.finish(RemessaImporter::Result.new(success: false, log: [ "Erro inesperado: #{e.message}" ], titulos_count: 0, titulos_rejeitados_count: 0))
    raise
  end
end
