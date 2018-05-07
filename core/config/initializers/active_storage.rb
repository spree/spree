class ActiveStorage::PurgeJob < ActiveStorage::BaseJob
  def perform(blob)
    blob.purge unless blob.attachments.present?
  end
end
