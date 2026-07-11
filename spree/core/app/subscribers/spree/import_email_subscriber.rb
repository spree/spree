# frozen_string_literal: true

module Spree
  # Emails the import's owner when processing finishes — including after a
  # failed-rows retry pass, which publishes `import.completed` again.
  # App-created imports (API key without an admin creator) have no recipient
  # and send nothing.
  #
  # We use async: false because this subscriber only enqueues the mail job.
  class ImportEmailSubscriber < Spree::Subscriber
    subscribes_to 'import.completed', async: false

    on 'import.completed', :send_import_done_email

    def send_import_done_email(event)
      import_id = event.payload['id']
      return unless import_id

      import = Spree::Import.find_by_prefix_id(import_id)
      return unless import
      return if import.user&.email.blank?

      Spree::ImportMailer.import_done(import).deliver_later
    end
  end
end
