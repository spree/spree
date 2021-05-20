class ActiveStorage::PurgeJob < ActiveStorage::BaseJob
  def perform(blob)
    blob.purge unless blob.attachments.present?
  end
end

Rails.application.config.active_storage.content_types_to_serve_as_binary.delete('image/svg+xml')
