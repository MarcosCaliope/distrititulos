# Tracks the live progress of a background remessa import (RemessaImportJob):
# persists state in Rails.cache (so a page reload/reopen still shows where
# things are) and broadcasts updates over Turbo Streams to whoever has the
# import's show page open. One instance per import id, id generated up front
# in RemessaImportsController#create before the job is enqueued.
class RemessaImportProgress
  EXPIRES_IN = 1.hour

  attr_reader :id

  def self.build_id
    SecureRandom.uuid
  end

  def initialize(id)
    @id = id
  end

  def start(filename)
    write(default_state.merge(filename: filename))
    broadcast_progress
  end

  def log(mensagem, processed:, total:)
    state = read
    state[:log] << mensagem
    state[:processed] = processed
    state[:total] = total
    write(state)
    broadcast_progress(state)
    broadcast_append_log(mensagem)
  end

  def finish(result)
    state = read.merge(
      status: result.success? ? "success" : "failed",
      titulos_count: result.titulos_count,
      titulos_rejeitados_count: result.titulos_rejeitados_count
    )
    write(state)
    broadcast_progress(state)
  end

  def state
    read
  end

  private

  def cache_key
    "remessa_import_progress/#{id}"
  end

  def stream_name
    "remessa_import_#{id}"
  end

  def default_state
    { status: "running", filename: nil, processed: 0, total: 0, titulos_count: 0, titulos_rejeitados_count: 0, log: [] }
  end

  def read
    Rails.cache.read(cache_key) || default_state
  end

  def write(state)
    Rails.cache.write(cache_key, state, expires_in: EXPIRES_IN)
  end

  def broadcast_progress(state = read)
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name,
      target: "remessa_import_progress",
      partial: "remessa_imports/progress",
      locals: { state: state }
    )
  end

  def broadcast_append_log(mensagem)
    Turbo::StreamsChannel.broadcast_append_to(
      stream_name,
      target: "remessa_import_log",
      partial: "remessa_imports/log_line",
      locals: { mensagem: mensagem }
    )
  end
end
